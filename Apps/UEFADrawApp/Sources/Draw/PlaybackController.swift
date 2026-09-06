// PlaybackController.swift
//
// Spielt eine fertige `[RevealStep]`-Sequenz mit steuerbarem Tempo ab.
//
// Weil die Sequenz vollstaendig vorliegt, ist die Steuerung simpel und robust:
// Pause ist ein angehaltener Cursor, Tempo ist eine Wartezeit, Replay ist Cursor
// auf 0. Bei gleichem Seed liefert die Engine dieselbe Sequenz - die Wiederholung
// ist damit garantiert identisch.
//
// Zwei Regeln halten die Zustaende widerspruchsfrei:
//
// 1. Tempo und Pause sind orthogonal. Eine Tempoauswahl setzt eine vom Nutzer
//    gesetzte Pause nicht auf. Einzige Ausnahme ist das Verlassen des
//    Schritt-Modus, dessen Pause zum Modus gehoert und nicht vom Nutzer kam.
// 2. Im Schritt-Modus gibt es keine automatische Wiedergabe. `resume()` ist dort
//    wirkungslos, sonst liefe die Auslosung mit Zeitfaktor 0 ohne Animation durch.

import Foundation
import Observation

@MainActor
@Observable
final class PlaybackController {

    enum Speed: String, CaseIterable, Identifiable, Sendable {
        case slow
        case normal
        case fast
        case manual

        var id: String { rawValue }

        /// Kurzform fuer die Leiste.
        var label: String {
            switch self {
            case .slow: "0,5×"
            case .normal: "1×"
            case .fast: "2×"
            case .manual: "Schritt"
            }
        }

        /// Ausgeschrieben fuer das Menue und die Sprachausgabe.
        var menuLabel: String {
            switch self {
            case .slow: "Langsam (0,5×)"
            case .normal: "Normal (1×)"
            case .fast: "Schnell (2×)"
            case .manual: "Schritt für Schritt"
            }
        }

        /// Faktor auf die Basisdauer. Groesser bedeutet langsamer.
        var timeScale: Double {
            switch self {
            case .slow: 2.0
            case .normal: 1.0
            case .fast: 0.5
            case .manual: 0
            }
        }
    }

    // MARK: - Zustand

    let steps: [RevealStep]

    private(set) var state = RevealState()
    private(set) var isPaused = false
    private(set) var speed: Speed = .normal

    /// Wird einmal aufgerufen, sobald die Sequenz durchgelaufen ist.
    var onCompleted: (() -> Void)?

    private var cursor = 0
    private var task: Task<Void, Never>?
    private var pauseGate: CheckedContinuation<Void, Never>?
    private var didReportCompletion = false
    /// Merkt, dass die Pause vom Schritt-Modus stammt und nicht vom Nutzer.
    /// Nur eine solche Pause darf beim Verlassen des Modus automatisch enden.
    private var pausedByModeSwitch = false

    init(steps: [RevealStep]) {
        self.steps = steps
    }

    // Kein deinit: der Zugriff auf isolierten Zustand waere unter strikter
    // Concurrency nicht erlaubt. Das ViewModel ruft `stop()` in `onDisappear`.

    // MARK: - Abgeleitete Anzeigewerte

    /// Laeuft die Wiedergabe gerade tatsaechlich weiter?
    ///
    /// Bewusst abgeleitet statt gespeichert: ein zweites Bool neben `isPaused`,
    /// `task` und `cursor` liesse Kombinationen zu, die es fachlich nicht gibt
    /// (etwa "laeuft" und "pausiert" gleichzeitig).
    var isRunning: Bool {
        task != nil && !isPaused && !isFinished
    }

    var progress: Double {
        steps.isEmpty ? 0 : Double(cursor) / Double(steps.count)
    }

    var canStepForward: Bool {
        cursor < steps.count
    }

    var isFinished: Bool {
        cursor >= steps.count
    }

    /// Im Schritt-Modus gibt es nichts zum Abspielen - die Leiste blendet die
    /// Wiedergabetaste entsprechend aus.
    var canTogglePlayback: Bool {
        speed != .manual && !isFinished
    }

    // MARK: - Steuerung

    func start() {
        guard task == nil, !isFinished, speed != .manual else { return }
        task = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func pause() {
        guard !isPaused, !isFinished else { return }
        isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        // Der Schritt-Modus kennt keine automatische Wiedergabe.
        guard speed != .manual else { return }

        isPaused = false
        pausedByModeSwitch = false
        releaseGate()
        if task == nil, !isFinished {
            start()
        }
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    func setSpeed(_ newSpeed: Speed) {
        guard newSpeed != speed else { return }

        let wasManual = (speed == .manual)
        speed = newSpeed

        if newSpeed == .manual {
            // Die Pause gehoert zum Modus - nur dann darf sie spaeter von
            // selbst enden. Eine bereits bestehende Nutzerpause bleibt seine.
            pausedByModeSwitch = !isPaused
            stop()
            pause()
        } else if wasManual, pausedByModeSwitch {
            pausedByModeSwitch = false
            resume()
        }
        // Sonst bewusst nichts: eine reine Tempoauswahl darf einen pausierten
        // Lauf nicht fortsetzen.
    }

    /// Ein Schritt weiter - fuer den manuellen Modus.
    func stepForward() {
        guard canStepForward else { return }
        advance()
        reportCompletionIfNeeded()
    }

    func replay() {
        stop()
        cursor = 0
        state = RevealState()
        didReportCompletion = false

        let manual = (speed == .manual)
        isPaused = manual
        pausedByModeSwitch = manual
        if !manual {
            start()
        }
    }

    /// Springt ohne Animation ans Ende.
    func skipToEnd() {
        stop()
        state = RevealState.reduce(steps[...])
        cursor = steps.count
        reportCompletionIfNeeded()
    }

    func stop() {
        task?.cancel()
        task = nil
        releaseGate()
    }

    // MARK: - Ablauf

    private func runLoop() async {
        while cursor < steps.count {
            if isPaused {
                await waitForResume()
            }
            if Task.isCancelled { break }
            guard cursor < steps.count else { break }

            let step = steps[cursor]
            advance()

            guard cursor < steps.count else { break }
            await wait(seconds: duration(for: step))
            if Task.isCancelled { break }
        }

        if !Task.isCancelled {
            task = nil
            reportCompletionIfNeeded()
        }
    }

    private func advance() {
        guard cursor < steps.count else { return }
        state.apply(steps[cursor])
        cursor += 1
    }

    /// Am Ende gibt es weder Pause noch offenen Modus-Zustand: eine fertige
    /// Auslosung darf in der Leiste kein "Fortsetzen" mehr anbieten.
    private func reportCompletionIfNeeded() {
        guard isFinished, !didReportCompletion else { return }
        didReportCompletion = true
        isPaused = false
        pausedByModeSwitch = false
        releaseGate()
        onCompleted?()
    }

    /// Wartet in kleinen Scheiben, damit Pause sofort greift statt erst
    /// nach Ablauf der vollen Schrittdauer.
    private func wait(seconds: Double) async {
        guard seconds > 0 else { return }
        let slice = 0.02
        var elapsed = 0.0
        while elapsed < seconds {
            if Task.isCancelled || isPaused { return }
            try? await Task.sleep(for: .seconds(slice))
            elapsed += slice
        }
    }

    private func waitForResume() async {
        while isPaused && !Task.isCancelled {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                if !isPaused || Task.isCancelled {
                    continuation.resume()
                } else {
                    pauseGate = continuation
                }
            }
        }
    }

    private func releaseGate() {
        pauseGate?.resume()
        pauseGate = nil
    }

    /// Basisdauer je Schrittart, skaliert mit dem gewaehlten Tempo.
    /// Ablehnungen stehen laenger, weil sie gelesen werden sollen.
    private func duration(for step: RevealStep) -> Double {
        let base: Double
        switch step {
        case .potOpened: base = 0.70
        case .teamDrawn: base = 0.90
        case .candidateRejected: base = 1.10
        case .opponentRevealed: base = 0.45
        case .teamCompleted: base = 0.50
        case .drawCompleted: base = 0
        }
        return base * speed.timeScale
    }
}
