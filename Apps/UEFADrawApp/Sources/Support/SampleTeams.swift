// SampleTeams.swift
//
// Startdaten fuer den Setup-Screen und die Previews: 36 Teams in 4 Toepfen.
// Reine Beispieldaten - die Zusammensetzung ist frei editierbar und traegt keine Regel.

import Foundation

enum SampleTeams {

    static let associations: [Association] = [
        Association(id: "ENG", name: "England"),
        Association(id: "ESP", name: "Spanien"),
        Association(id: "GER", name: "Deutschland"),
        Association(id: "ITA", name: "Italien"),
        Association(id: "FRA", name: "Frankreich"),
        Association(id: "POR", name: "Portugal"),
        Association(id: "NED", name: "Niederlande"),
        Association(id: "AUT", name: "Oesterreich"),
        Association(id: "BEL", name: "Belgien"),
        Association(id: "SCO", name: "Schottland"),
        Association(id: "CRO", name: "Kroatien"),
        Association(id: "CZE", name: "Tschechien"),
        Association(id: "SUI", name: "Schweiz"),
        Association(id: "SRB", name: "Serbien"),
        Association(id: "SVK", name: "Slowakei"),
        Association(id: "UKR", name: "Ukraine")
    ]

    private static func association(_ id: String) -> Association {
        associations.first { $0.id == id }
            ?? Association(id: id, name: id)
    }

    /// Vier Toepfe mit je neun Teams.
    static func defaultPots() -> [Pot] {
        let layout: [[(String, String)]] = [
            [
                ("Real Madrid", "ESP"), ("Manchester City", "ENG"), ("Bayern Muenchen", "GER"),
                ("Paris Saint-Germain", "FRA"), ("Liverpool", "ENG"), ("Inter Mailand", "ITA"),
                ("Borussia Dortmund", "GER"), ("RB Leipzig", "GER"), ("FC Barcelona", "ESP")
            ],
            [
                ("Bayer Leverkusen", "GER"), ("Atletico Madrid", "ESP"), ("Atalanta Bergamo", "ITA"),
                ("Juventus Turin", "ITA"), ("Benfica Lissabon", "POR"), ("Arsenal", "ENG"),
                ("Club Bruegge", "BEL"), ("Schachtar Donezk", "UKR"), ("AC Mailand", "ITA")
            ],
            [
                ("Feyenoord Rotterdam", "NED"), ("Sporting Lissabon", "POR"), ("PSV Eindhoven", "NED"),
                ("Dinamo Zagreb", "CRO"), ("RB Salzburg", "AUT"), ("OSC Lille", "FRA"),
                ("Roter Stern Belgrad", "SRB"), ("Young Boys Bern", "SUI"), ("Celtic Glasgow", "SCO")
            ],
            [
                ("Slovan Bratislava", "SVK"), ("AS Monaco", "FRA"), ("Sparta Prag", "CZE"),
                ("Aston Villa", "ENG"), ("FC Bologna", "ITA"), ("FC Girona", "ESP"),
                ("VfB Stuttgart", "GER"), ("Sturm Graz", "AUT"), ("Stade Brest", "FRA")
            ]
        ]

        return layout.enumerated().map { index, entries in
            let potIndex = index + 1
            let teams = entries.map { name, associationID in
                Team(name: name, association: association(associationID), potIndex: potIndex)
            }
            return Pot(id: potIndex, teams: teams)
        }
    }

    static func defaultSetup(enabledConstraintIDs: Set<String>) -> DrawSetup {
        DrawSetup(pots: defaultPots(), enabledConstraintIDs: enabledConstraintIDs)
    }

    /// Fertiger Beispiel-Lauf fuer Previews und Tests.
    static func previewRun(seed: UInt64 = 2_026) async -> DrawRun {
        let engine = MockDrawEngine()
        let setup = defaultSetup(
            enabledConstraintIDs: Set(engine.availableConstraints().map(\.id))
        )
        // Der Fake wirft nur bei struktureller Fehlkonfiguration - hier ausgeschlossen.
        return (try? await engine.run(setup: setup, seed: seed))
            ?? DrawRun(setup: setup, matchups: [], trace: [], seed: seed)
    }
}
