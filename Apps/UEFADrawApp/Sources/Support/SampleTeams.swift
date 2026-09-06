// SampleTeams.swift
//
// Startdaten fuer den Setup-Screen und die Previews: die 36 Teams der
// Ligaphase 2026/27 mit den Wappen aus Resources/Design.
//
// Namen und Wappen stammen aus Resources/Design/teams-manifest.json.
// Die Verbands- und Topf-Zuordnung steht dort NICHT und ist hier gesetzt:
// die Verbaende sind sachlich korrekt, die Topf-Einteilung ist eine plausible
// Annahme und im Setup-Screen frei aenderbar. Sie ist Beispieldatenlage,
// keine Regel - Regeln gehoeren ausschliesslich in die Draw-Engine.

import Foundation

enum SampleTeams {

    static let associations: [Association] = [
        Association(id: "AUT", name: "Österreich"),
        Association(id: "AZE", name: "Aserbaidschan"),
        Association(id: "BEL", name: "Belgien"),
        Association(id: "CZE", name: "Tschechien"),
        Association(id: "ENG", name: "England"),
        Association(id: "ESP", name: "Spanien"),
        Association(id: "FRA", name: "Frankreich"),
        Association(id: "GER", name: "Deutschland"),
        Association(id: "GRE", name: "Griechenland"),
        Association(id: "ITA", name: "Italien"),
        Association(id: "NED", name: "Niederlande"),
        Association(id: "NOR", name: "Norwegen"),
        Association(id: "POR", name: "Portugal"),
        Association(id: "SVK", name: "Slowakei"),
        Association(id: "TUR", name: "Türkei"),
        Association(id: "UKR", name: "Ukraine")
    ]

    private static func association(_ id: String) -> Association {
        associations.first { $0.id == id } ?? Association(id: id, name: id)
    }

    /// Name, Verband und Wappen-Slug je Topf. Der Slug entspricht dem Bildsatz
    /// im Asset-Katalog und dem Dateinamen im Manifest.
    private static let layout: [[(name: String, association: String, logo: String)]] = [
        [
            ("Real Madrid", "ESP", "real-madrid"),
            ("Manchester City", "ENG", "manchester-city"),
            ("Bayern München", "GER", "bayern-munich"),
            ("Paris Saint-Germain", "FRA", "paris-saint-germain"),
            ("Liverpool", "ENG", "liverpool"),
            ("Inter Mailand", "ITA", "inter"),
            ("Borussia Dortmund", "GER", "borussia-dortmund"),
            ("FC Barcelona", "ESP", "barcelona"),
            ("Arsenal", "ENG", "arsenal")
        ],
        [
            ("Atlético Madrid", "ESP", "atletico-madrid"),
            ("SSC Neapel", "ITA", "napoli"),
            ("FC Porto", "POR", "porto"),
            ("Sporting Lissabon", "POR", "sporting-cp"),
            ("Club Brügge", "BEL", "club-brugge"),
            ("Schachtar Donezk", "UKR", "shakhtar-donetsk"),
            ("Aston Villa", "ENG", "aston-villa"),
            ("Manchester United", "ENG", "manchester-united"),
            ("AS Rom", "ITA", "as-roma")
        ],
        [
            ("Feyenoord Rotterdam", "NED", "feyenoord"),
            ("PSV Eindhoven", "NED", "psv-eindhoven"),
            ("FC Villarreal", "ESP", "villarreal"),
            ("OSC Lille", "FRA", "lille"),
            ("Fenerbahçe", "TUR", "fenerbahce"),
            ("Galatasaray", "TUR", "galatasaray"),
            ("Real Betis", "ESP", "real-betis"),
            ("RC Lens", "FRA", "rc-lens"),
            ("Slavia Prag", "CZE", "slavia-praha")
        ],
        [
            ("Como 1907", "ITA", "como"),
            ("VfB Stuttgart", "GER", "vfb-stuttgart"),
            ("Bodø/Glimt", "NOR", "bodo-glimt"),
            ("AEK Athen", "GRE", "aek-athens"),
            ("LASK", "AUT", "lask"),
            ("Sabah FK", "AZE", "sabah"),
            ("Viking FK", "NOR", "viking-fk"),
            ("Slovan Bratislava", "SVK", "slovan-bratislava"),
            ("RB Leipzig", "GER", "rb-leipzig")
        ]
    ]

    /// Vier Toepfe mit je neun Teams.
    static func defaultPots() -> [Pot] {
        layout.enumerated().map { index, entries in
            let potIndex = index + 1
            let teams = entries.map { entry in
                Team(
                    name: entry.name,
                    association: association(entry.association),
                    potIndex: potIndex,
                    logoName: entry.logo
                )
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
