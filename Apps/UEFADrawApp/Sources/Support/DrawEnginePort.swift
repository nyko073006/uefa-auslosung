// DrawEnginePort.swift
//
// Die Naht zwischen SwiftUI-Shell und Draw-Engine.
//
// Dieses Protokoll beschreibt ausschliesslich, was die UI von der Engine braucht.
// Es enthaelt keine Regel und keine Bewertung - beides gehoert hinter diese Grenze.
//
// BEIM MERGE mit feature/draw-engine: eine Adapter-Implementierung anlegen, die den
// echten Engine-Typ auf dieses Protokoll abbildet. Views und ViewModels bleiben
// unveraendert, weil sie nur gegen `DrawEnginePort` arbeiten.

import Foundation

// MARK: - Protokoll

protocol DrawEnginePort: Sendable {

    /// Welche Regeln kennt die Engine? Der Setup-Screen rendert daraus seine Toggles.
    /// Ohne das muesste die App Regelnamen hart kodieren - genau das soll sie nicht.
    func availableConstraints() -> [ConstraintDescriptor]

    /// Fachliche Pruefung der Konfiguration. Ob 36 Teams oder 9 pro Topf gelten,
    /// entscheidet die Engine, nicht die UI.
    func validate(_ setup: DrawSetup) -> [SetupIssue]

    /// Fuehrt die Auslosung aus. Deterministisch fuer einen gegebenen Seed.
    func run(setup: DrawSetup, seed: UInt64) async throws -> DrawRun
}

// MARK: - Eingang

/// Konfiguration einer Auslosung: Toepfe plus aktivierte Regeln.
struct DrawSetup: Hashable, Sendable {
    var pots: [Pot]
    var enabledConstraintIDs: Set<String>

    init(pots: [Pot], enabledConstraintIDs: Set<String>) {
        self.pots = pots
        self.enabledConstraintIDs = enabledConstraintIDs
    }

    var allTeams: [Team] {
        pots.flatMap(\.teams)
    }

    var teamsByID: [Team.ID: Team] {
        Dictionary(uniqueKeysWithValues: allTeams.map { ($0.id, $0) })
    }
}

/// Eine von der Engine deklarierte Regel. Titel und Erklaertext kommen aus der Engine,
/// damit die UI sie anzeigen kann, ohne sie zu kennen.
struct ConstraintDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let explanation: String

    init(id: String, title: String, explanation: String) {
        self.id = id
        self.title = title
        self.explanation = explanation
    }
}

/// Befund aus `validate(_:)`. Blockierende Issues verhindern den Start.
struct SetupIssue: Identifiable, Hashable, Sendable {
    enum Severity: Hashable, Sendable {
        case blocking
        case warning
    }

    let id: String
    let severity: Severity
    let message: String
    /// Optionaler Bezug auf einen Topf, damit die UI die Meldung verorten kann.
    let potIndex: Int?

    init(id: String, severity: Severity, message: String, potIndex: Int? = nil) {
        self.id = id
        self.severity = severity
        self.message = message
        self.potIndex = potIndex
    }
}

// MARK: - Ausgang

/// Das Ergebnis eines Laufs: finale Paarungen plus der Entscheidungsverlauf.
///
/// `trace` ist die Grundlage fuer den erklaerenden Live-Screen. docs/architecture.md
/// sagt diesen Ausgang zu ("Ergebnisse, Zwischenstaende, Ablehnungen und Begruendungen").
struct DrawRun: Hashable, Sendable {
    let setup: DrawSetup
    let matchups: [Matchup]
    let trace: [DrawTraceEntry]
    /// Der tatsaechlich verwendete Seed - auch wenn er zufaellig gewaehlt wurde.
    /// Nur damit ist ein Ergebnis teilbar und der Replay reproduzierbar.
    let seed: UInt64

    init(setup: DrawSetup, matchups: [Matchup], trace: [DrawTraceEntry], seed: UInt64) {
        self.setup = setup
        self.matchups = matchups
        self.trace = trace
        self.seed = seed
    }

    func matchups(for teamID: Team.ID) -> [Matchup] {
        matchups.filter { $0.teamID == teamID }
    }
}

/// Ein einzelner Zuweisungsversuch aus dem Engine-Lauf.
struct DrawTraceEntry: Identifiable, Hashable, Sendable {
    enum Outcome: Hashable, Sendable {
        case accepted(venue: Venue)
        /// Der Begruendungstext wird von der Engine formuliert. Die UI zeigt ihn nur an.
        case rejected(reason: String)
    }

    let id: UUID
    let teamID: Team.ID
    let candidateID: Team.ID
    let candidatePot: Int
    let outcome: Outcome

    init(
        id: UUID = UUID(),
        teamID: Team.ID,
        candidateID: Team.ID,
        candidatePot: Int,
        outcome: Outcome
    ) {
        self.id = id
        self.teamID = teamID
        self.candidateID = candidateID
        self.candidatePot = candidatePot
        self.outcome = outcome
    }
}

// MARK: - Fehler

enum DrawEngineError: LocalizedError, Sendable {
    case invalidSetup([SetupIssue])
    case noValidDraw(seed: UInt64)

    var errorDescription: String? {
        switch self {
        case .invalidSetup(let issues):
            let list = issues.map(\.message).joined(separator: ", ")
            return "Die Konfiguration ist nicht gueltig: \(list)"
        case .noValidDraw(let seed):
            return "Mit dem Seed \(seed) liess sich keine gueltige Auslosung finden."
        }
    }
}
