// MockDrawEngine.swift
//
// ACHTUNG - FAKE, KEINE ENGINE.
//
// Erzeugt ein *strukturell* plausibles Ergebnis, damit Previews und UI-Entwicklung
// ohne die echte Draw-Engine laufen. Der Aufbau ist fest verdrahtet (Circulant-Muster),
// nicht ausgelost:
//
//   - jedes Team bekommt 8 Gegner, davon 2 aus jedem Topf
//   - jedes Team hat 4 Heim- und 4 Auswaertsspiele
//
// Association-Regeln implementiert dieser Fake bewusst NICHT. Wuerde er Regeln
// nachbauen, waere genau das das verbotene Duplikat der Engine-Logik. Die Begruendungs-
// texte im Trace sind Beispieltexte fuer die Darstellung, keine echte Bewertung.
//
// BEIM MERGE: durch einen Adapter auf die echte DrawEngine ersetzen.

import Foundation

struct MockDrawEngine: DrawEnginePort {

    private let teamsPerPot = 9
    private let potCount = 4

    // MARK: - DrawEnginePort

    func availableConstraints() -> [ConstraintDescriptor] {
        [
            ConstraintDescriptor(
                id: "no-same-association",
                title: "Kein Duell im eigenen Verband",
                explanation: "Zwei Teams aus demselben nationalen Verband treffen nicht aufeinander."
            ),
            ConstraintDescriptor(
                id: "max-two-per-association",
                title: "Höchstens zwei Gegner je Verband",
                explanation: "Kein Team bekommt mehr als zwei Gegner aus demselben Verband."
            )
        ]
    }

    func validate(_ setup: DrawSetup) -> [SetupIssue] {
        // Platzhalter-Pruefung. Die fachliche Validierung gehoert in die Engine -
        // hier stehen nur die Struktur-Checks, die der Fake fuer sein Muster braucht.
        var issues: [SetupIssue] = []

        for pot in setup.pots where pot.teams.count != teamsPerPot {
            issues.append(
                SetupIssue(
                    id: "pot-\(pot.id)-size",
                    severity: .blocking,
                    message: "Topf \(pot.id) hat \(pot.teams.count) statt \(teamsPerPot) Teams.",
                    potIndex: pot.id
                )
            )
        }

        if setup.pots.count != potCount {
            issues.append(
                SetupIssue(
                    id: "pot-count",
                    severity: .blocking,
                    message: "Es werden \(potCount) Töpfe erwartet, gefunden: \(setup.pots.count)."
                )
            )
        }

        let unnamed = setup.allTeams.filter { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        if !unnamed.isEmpty {
            issues.append(
                SetupIssue(
                    id: "unnamed-teams",
                    severity: .blocking,
                    message: "\(unnamed.count) Team(s) ohne Namen."
                )
            )
        }

        return issues
    }

    func run(setup: DrawSetup, seed: UInt64) async throws -> DrawRun {
        let blocking = validate(setup).filter { $0.severity == .blocking }
        guard blocking.isEmpty else {
            throw DrawEngineError.invalidSetup(blocking)
        }

        // Kleine Kunstpause, damit der Ladezustand im Live-Screen sichtbar ist.
        try? await Task.sleep(for: .milliseconds(600))

        let pots = setup.pots.sorted { $0.id < $1.id }
        let matchups = buildMatchups(pots: pots)
        let trace = buildTrace(pots: pots, matchups: matchups, seed: seed)

        return DrawRun(setup: setup, matchups: matchups, trace: trace, seed: seed)
    }

    // MARK: - Struktur

    /// Baut ein festes Muster, das die Mengenbedingungen exakt erfuellt.
    ///
    /// Gleicher Topf: Ring j -> j+1, die Vorwaertskante ist Heimspiel.
    /// Topf p gegen q (p < q): p[j] hat Heim gegen q[j] und Auswaerts gegen q[j+1].
    /// Dadurch kommt jedes Team auf 1 Heim- und 1 Auswaertsspiel je Topf.
    private func buildMatchups(pots: [Pot]) -> [Matchup] {
        var result: [Matchup] = []

        func add(_ home: Team, _ away: Team) {
            result.append(
                Matchup(teamID: home.id, opponentID: away.id, venue: .home, opponentPot: away.potIndex)
            )
            result.append(
                Matchup(teamID: away.id, opponentID: home.id, venue: .away, opponentPot: home.potIndex)
            )
        }

        for pot in pots {
            let teams = pot.teams
            guard teams.count == teamsPerPot else { continue }
            for j in 0..<teamsPerPot {
                add(teams[j], teams[(j + 1) % teamsPerPot])
            }
        }

        for pIndex in 0..<pots.count {
            for qIndex in (pIndex + 1)..<pots.count {
                let p = pots[pIndex].teams
                let q = pots[qIndex].teams
                guard p.count == teamsPerPot, q.count == teamsPerPot else { continue }
                for j in 0..<teamsPerPot {
                    add(p[j], q[j])
                    add(q[(j + 1) % teamsPerPot], p[j])
                }
            }
        }

        return result
    }

    /// Baut einen Beispiel-Trace: je Zuweisung eine Annahme, gelegentlich eine
    /// vorangestellte Ablehnung, damit der Live-Screen seine Erklaerung zeigen kann.
    private func buildTrace(pots: [Pot], matchups: [Matchup], seed: UInt64) -> [DrawTraceEntry] {
        var random = SplitMix64(seed: seed)
        let allTeams = pots.flatMap(\.teams)
        let byID = Dictionary(uniqueKeysWithValues: allTeams.map { ($0.id, $0) })
        var trace: [DrawTraceEntry] = []

        for team in allTeams {
            let assigned = matchups
                .filter { $0.teamID == team.id }
                .sorted { $0.opponentPot < $1.opponentPot }

            let assignedOpponentIDs = Set(assigned.map(\.opponentID))

            for matchup in assigned {
                if random.next() % 4 == 0,
                   let rejected = sampleRejection(
                       for: team,
                       among: allTeams,
                       assignedOpponentIDs: assignedOpponentIDs,
                       using: &random
                   ) {
                    trace.append(
                        DrawTraceEntry(
                            teamID: team.id,
                            candidateID: rejected.candidate.id,
                            candidatePot: rejected.candidate.potIndex,
                            outcome: .rejected(reason: rejected.reason)
                        )
                    )
                }

                guard let opponent = byID[matchup.opponentID] else { continue }
                trace.append(
                    DrawTraceEntry(
                        teamID: team.id,
                        candidateID: opponent.id,
                        candidatePot: opponent.potIndex,
                        outcome: .accepted(venue: matchup.venue)
                    )
                )
            }
        }

        return trace
    }

    /// Waehlt einen Kandidaten, der diesem Team NICHT zugelost wurde, und gibt
    /// einen bewusst neutralen Begruendungstext zurueck.
    ///
    /// Der Text nennt absichtlich keine Regel: der Fake prueft keine, und eine
    /// erfundene Begruendung wuerde sich mit den erzeugten Paarungen widersprechen
    /// (er wuerde einen Verband ablehnen, den er an anderer Stelle zulaesst).
    /// Im Echtbetrieb formuliert die Engine hier den fachlichen Satz.
    private func sampleRejection(
        for team: Team,
        among teams: [Team],
        assignedOpponentIDs: Set<Team.ID>,
        using random: inout SplitMix64
    ) -> (candidate: Team, reason: String)? {
        let candidates = teams.filter {
            $0.id != team.id && !assignedOpponentIDs.contains($0.id)
        }
        guard !candidates.isEmpty else { return nil }

        let candidate = candidates[Int(random.next() % UInt64(candidates.count))]
        let reason = "Beispielhafte Ablehnung des Platzhalters – die echte Engine "
            + "liefert hier ihre fachliche Begründung."
        return (candidate, reason)
    }
}

// MARK: - Deterministischer Zufall fuer den Fake

/// Kleiner, deterministischer PRNG, damit der Beispiel-Trace bei gleichem Seed
/// identisch bleibt. Der echte Zufall der Auslosung gehoert in die Engine.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
