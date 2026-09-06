// LiveDrawViewModel.swift
//
// Bindeglied zwischen Engine-Lauf, Enthuellung und View.
// Die View liest hier nur fertige Anzeigewerte ab und trifft keine Entscheidung.

import Foundation
import Observation

@MainActor
@Observable
final class LiveDrawViewModel {

    enum Phase: Equatable {
        case preparing
        case revealing
        case finished
        case failed(String)
    }

    // MARK: - Abhaengigkeiten

    private let setup: DrawSetup
    private let seed: UInt64
    private let port: any DrawEnginePort
    private let router: AppRouter

    // MARK: - Zustand

    private(set) var phase: Phase = .preparing
    private(set) var playback: PlaybackController?
    private(set) var run: DrawRun?

    private let teamsByID: [Team.ID: Team]
    /// Schranke gegen den Doppelstart. `phase` allein genuegt nicht: sie wechselt
    /// erst nach `await port.run(...)`, ein zweiter Eintritt waehrend des Laufs
    /// kaeme also durch und wuerde die Engine erneut starten.
    private var isLoading = false

    init(setup: DrawSetup, seed: UInt64, port: any DrawEnginePort, router: AppRouter) {
        self.setup = setup
        self.seed = seed
        self.port = port
        self.router = router
        self.teamsByID = setup.teamsByID
    }

    // MARK: - Lebenszyklus

    func load() async {
        guard !isLoading, case .preparing = phase else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let run = try await port.run(setup: setup, seed: seed)
            try Task.checkCancellation()
            self.run = run

            let controller = PlaybackController(steps: RevealSequencer.steps(for: run))
            controller.onCompleted = { [weak self] in
                self?.handleCompletion()
            }
            self.playback = controller
            phase = .revealing
            controller.start()
        } catch is CancellationError {
            // Ein Abbruch ist kein Fehler: er entsteht, wenn der Nutzer den
            // Screen verlaesst. Ein Fehlerdialog waere hier schlicht falsch.
            phase = .preparing
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func teardown() {
        playback?.stop()
    }

    // MARK: - Anzeigewerte

    var state: RevealState {
        playback?.state ?? RevealState()
    }

    var currentTeam: Team? {
        state.currentTeamID.flatMap { teamsByID[$0] }
    }

    var openPot: Int? {
        state.openPot
    }

    /// Bereits aufgedeckte Gegner des laufenden Teams, nach Topf sortiert.
    var revealedOpponents: [(opponent: RevealedOpponent, team: Team)] {
        state.revealedOpponents.compactMap { revealed in
            guard let team = teamsByID[revealed.id] else { return nil }
            return (opponent: revealed, team: team)
        }
    }

    /// Aktuelle Ablehnung inklusive Klarnamen. Der Begruendungstext kommt
    /// unveraendert aus der Engine - die App formuliert ihn nicht selbst.
    var activeRejection: (team: Team, reason: String)? {
        guard let rejection = state.activeRejection,
              let team = teamsByID[rejection.candidate] else { return nil }
        return (team: team, reason: rejection.reason)
    }

    /// Verteilung der bisherigen Gegner nach Verband. Reine Auszaehlung ohne Urteil,
    /// ob eine Anzahl noch zulaessig ist - das entscheidet allein die Engine.
    var associationTally: [(association: Association, count: Int)] {
        let counts = revealedOpponents.reduce(into: [Association: Int]()) { partial, entry in
            partial[entry.team.association, default: 0] += 1
        }
        return counts
            .map { (association: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.count == rhs.count
                    ? lhs.association.id < rhs.association.id
                    : lhs.count > rhs.count
            }
    }

    var pots: [Pot] {
        setup.pots
    }

    var potIDs: [Int] {
        setup.pots.map(\.id).sorted()
    }

    /// Wie viele Gegner ein Team bekommt - **abgelesen** aus dem Engine-Ergebnis,
    /// nicht als Regel angenommen. Aendert die Engine ihr Format, folgt die UI.
    var opponentsPerTeam: Int {
        guard let run else { return 0 }
        return run.setup.allTeams
            .map { run.matchups(for: $0.id).count }
            .max() ?? 0
    }

    /// Wie viele Gegner je Topf zu erwarten sind - ebenfalls aus dem Ergebnis abgelesen.
    var opponentsPerPot: Int {
        guard let run, let referenceTeam = run.setup.allTeams.first else { return 0 }
        let grouped = Dictionary(grouping: run.matchups(for: referenceTeam.id), by: \.opponentPot)
        return grouped.values.map(\.count).max() ?? 0
    }

    var completedTeamCount: Int {
        state.completedTeamIDs.count
    }

    var totalTeamCount: Int {
        setup.allTeams.count
    }

    var progress: Double {
        playback?.progress ?? 0
    }

    var remainingByPot: [Int: Int] {
        let completed = Set(state.completedTeamIDs)
        return setup.pots.reduce(into: [:]) { partial, pot in
            partial[pot.id] = pot.teams.filter { !completed.contains($0.id) }.count
        }
    }

    func team(for id: Team.ID) -> Team? {
        teamsByID[id]
    }

    // MARK: - Aktionen

    func retry() async {
        // Die alte Wiedergabe zuerst stoppen. Sonst laeuft sie weiter, ist ueber
        // das ViewModel nicht mehr erreichbar und wuerde am Ende erneut
        // `router.replaceTop` ausloesen.
        playback?.stop()
        playback = nil
        run = nil
        phase = .preparing
        await load()
    }

    func skipToResult() {
        playback?.skipToEnd()
    }

    private func handleCompletion() {
        phase = .finished
        guard let run else { return }
        // Ersetzen statt Anhaengen: "Zurueck" soll nicht in eine bereits
        // abgelaufene Auslosung zurueckfuehren.
        router.replaceTop(with: .results(run))
    }
}
