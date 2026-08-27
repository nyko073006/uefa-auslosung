// PlaybackController.swift
//
// Spielt eine fertige `[RevealStep]`-Sequenz mit steuerbarem Tempo ab.
//
// Weil die Sequenz vollstaendig vorliegt, ist die Steuerung simpel und robust:
// Pause ist ein angehaltener Cursor, Tempo ist eine Wartezeit, Replay ist Cursor
// auf 0. Bei gleichem Seed liefert die Engine dieselbe Sequenz - die Wiederholung
// ist damit garantiert identisch.

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
    private(set) var isRunning = false
    private(set) var speed: Speed = .normal

    /// Wird einmal aufgerufen, sobald die Sequenz durchgelaufen ist.
    var onCompleted: (() -> Void)?

    private var cursor = 0
    private var task: Task<Void, Never>?
    private var pauseGate: CheckedContinuation<Void, Never>?
    private var didReportCompletion = false

    init(steps: [RevealStep]) {
        self.steps = steps
    }

    // Kein deinit: der Zugriff auf isolierten Zustand waere unter strikter
    // Concurrency nicht erlaubt. Das ViewModel ruft `stop()` in `onDisappear`.

    // MARK: - Abgeleitete Anzeigewerte

    var progress: Double {
        steps.isEmpty ? 0 : Double(cursor) / Double(steps.count)
    }

    var canStepForward: Bool {
        cursor < steps.count
    }

    var isFinished: Bool {
        cursor >= steps.count
    }

    // MARK: - Steuerung

    func start() {
        guard task == nil, !isFinished else { return }
        isRunning = true
        task = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        releaseGate()
        if task == nil && !isFinished {
            start()
        }
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    func setSpeed(_ newSpeed: Speed) {
        speed = newSpeed
        if newSpeed == .manual {
            pause()
        } else {
            resume()
        }
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
        isPaused = (speed == .manual)
        if !isPaused {
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
        isRunning = false
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

        isRunning = false
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

    private func reportCompletionIfNeeded() {
        guard isFinished, !didReportCompletion else { return }
        didReportCompletion = true
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
