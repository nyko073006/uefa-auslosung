import Testing
@testable import DrawEngine

// MARK: - Lokale Testdaten
//
// Gebaut wird mit `Fixtures.makeTeams(potLayout:)` aus der gemeinsamen
// `Fixtures.swift`; nur die Verteilungen selbst liegen hier. Sie sind bewusst
// `private` und tragen den eindeutigen Praefix `unsolvable...`, damit sie mit
// spaeteren Bausteinen in `Fixtures` nicht kollidieren koennen.

// MARK: Das beweisbar unloesbare Feld

/// Verbandsverteilung eines Feldes, das jede billige Vorab-Schranke besteht und
/// trotzdem beweisbar keine Loesung hat.
///
/// ## Aufbau
/// - Topf 1: Verband AAA vier Mal, Verband BBB vier Mal, Verband CCC ein Mal
/// - Topf 2: AAA drei Mal, BBB drei Mal, dazu drei Einzelverbaende
/// - Toepfe 3 und 4: 18 verschiedene Einzelverbaende
///
/// ## Warum die Vorpruefung nichts findet
/// Alle drei notwendigen Bedingungen aus `InputValidation` sind erfuellt:
/// - Gesamtanzahl je Verband: AAA hat 4 + 3 = 7, BBB ebenso 7, Schranke ist 7.
/// - Anzahl je Topf: hoechstens 4 (AAA und BBB in Topf 1), Schranke ist 4.
/// - Anzahl je Topfpaar: hoechstens 4 + 3 = 7, Schranke ist 9.
///
/// Die Vorpruefung prueft nur notwendige, keine hinreichenden Bedingungen. Genau
/// deshalb taugt dieses Feld als Test des Backtracking-Pfades: Es kommt an den
/// billigen Schranken vorbei und muss von der Suche selbst widerlegt werden.
///
/// ## Beweis der Unloesbarkeit
/// Betrachte nur den Teilgraphen innerhalb von Topf 1. Jedes der neun Teams
/// braucht dort genau zwei Gegner, Duelle im eigenen Verband sind verboten. Es
/// gibt also nur Kanten zwischen verschiedenen Verbaenden. Sei `x` die Zahl der
/// AAA-BBB-Kanten, `y` die der AAA-CCC-Kanten und `z` die der BBB-CCC-Kanten.
/// Die Gradsummen je Verbandsseite sind damit:
///
///     AAA-Seite: x + y = 2 * 4 = 8
///     BBB-Seite: x + z = 2 * 4 = 8
///     CCC-Seite: y + z = 2 * 1 = 2
///
/// Die ersten beiden Gleichungen liefern y = z, mit der dritten also y = z = 1
/// und x = 7. Die Loesung ist eindeutig: Jede gueltige Belegung von Topf 1 hat
/// genau sieben AAA-BBB-Kanten.
///
/// Diese sieben AAA-Kanten verteilen sich auf die vier BBB-Teams, von denen
/// keines mehr als zwei Gegner desselben Verbands haben darf. Die einzige
/// Verteilung von 7 auf vier Werte mit Hoechstwert 2 ist (2, 2, 2, 1): Drei
/// BBB-Teams haben ihre AAA-Obergrenze schon innerhalb von Topf 1
/// ausgeschoepft, eines hat noch genau einen freien AAA-Platz. Das CCC-Team hat
/// wegen y = 1 ebenfalls noch genau einen freien AAA-Platz.
///
/// In Topf 1 bleiben damit insgesamt **zwei** Plaetze, die noch einen Gegner aus
/// AAA aufnehmen koennen. Die drei AAA-Teams in Topf 2 brauchen aber je zwei
/// Gegner aus Topf 1, zusammen also **sechs** solche Plaetze. Wegen 6 > 2 ist
/// jede Fortsetzung einer beliebigen gueltigen Topf-1-Belegung unmoeglich, und
/// da jede Loesung eine solche Belegung enthalten muesste, existiert keine
/// Loesung.
///
/// Der Beweis benutzt den Zufall an keiner Stelle. Unloesbarkeit ist eine
/// Eigenschaft der Eingabe, nicht des Seeds - deshalb pruefen die Tests unten
/// mehrere Seeds und erwarten bei jedem denselben Ausgang.
private let unsolvablePotLayout: [[String]] = [
    ["AAA", "AAA", "AAA", "AAA", "BBB", "BBB", "BBB", "BBB", "CCC"],
    ["AAA", "AAA", "AAA", "BBB", "BBB", "BBB", "S01", "S02", "S03"],
    ["S04", "S05", "S06", "S07", "S08", "S09", "S10", "S11", "S12"],
    ["S13", "S14", "S15", "S16", "S17", "S18", "S19", "S20", "S21"],
]

/// Das beweisbar unloesbare Feld aus 36 Teams.
private let unsolvableFeld: [Team] = Fixtures.makeTeams(potLayout: unsolvablePotLayout)

// MARK: Kontrastgruppe - schon von der Vorpruefung erwischt

/// Verbandsverteilung mit acht Teams desselben Verbands.
///
/// AAA steht vier Mal in Topf 1 und vier Mal in Topf 2. Die Schranke "hoechstens
/// vier je Topf" ist damit noch eingehalten, die Schranke "hoechstens sieben
/// insgesamt" aber nicht. Das ist die Kontrastgruppe zum Feld oben: ebenfalls
/// unloesbar, aber so offensichtlich, dass die Suche gar nicht erst anlaeuft.
private let unsolvableEarlyRejectPotLayout: [[String]] = [
    ["AAA", "AAA", "AAA", "AAA", "E01", "E02", "E03", "E04", "E05"],
    ["AAA", "AAA", "AAA", "AAA", "E06", "E07", "E08", "E09", "E10"],
    ["E11", "E12", "E13", "E14", "E15", "E16", "E17", "E18", "E19"],
    ["E20", "E21", "E22", "E23", "E24", "E25", "E26", "E27", "E28"],
]

/// Das Feld mit acht Teams desselben Verbands.
private let unsolvableEarlyRejectFeld: [Team] = Fixtures.makeTeams(potLayout: unsolvableEarlyRejectPotLayout)

/// Der Fehler, den die Vorpruefung fuer die Kontrastgruppe melden muss.
private let unsolvableEarlyRejectError: DrawError = .infeasibleAssociationDistribution(
    association: Association("AAA"),
    reason: .tooManyTeamsTotal(count: 8)
)

// MARK: Seeds und Budgets

/// Seeds, ueber die die Unloesbarkeit geprueft wird.
///
/// Fuenf verschiedene Kandidatenreihenfolgen genuegen: Der Seed steuert allein,
/// in welcher Reihenfolge die Suche die Kandidaten probiert. Er kann damit
/// beeinflussen, wie lange sie sucht, aber nicht, ob sie etwas findet.
private let unsolvableSeeds: [UInt64] = [1, 2, 3, 42, 4711]

/// Tatsaechlicher Suchaufwand des Widerspruchsbeweises, in Kantenplatzierungen.
///
/// Gemessen ueber die Budget-Grenze: Bis einschliesslich `4` meldet die Suche
/// `searchBudgetExceeded`, ab `5` meldet sie `unsolvable`. Der Wert ist fuer
/// alle geprueften Seeds identisch, und das ist kein Zufall: Um Unloesbarkeit
/// festzustellen, muss der gesamte Suchraum durchlaufen werden. Die
/// Kandidatenreihenfolge aendert dabei die Reihenfolge der Zweige, nicht deren
/// Anzahl.
///
/// ## Bewusste Aenderung: frueher standen hier 33_317 Knoten
/// Der Wert ist durch den Fix an den Forward-Checks gefallen, nicht durch eine
/// Aenderung am Fixture. Der neue globale Verbands-Check
/// (`Search.globalAssociationCheckPasses`) rechnet je Association und Zieltopf
/// ueber alle Toepfe hinweg und faellt im Ausgangszustand auf die geschlossene
/// Form `m + k <= 9` zusammen (`m` Teams des Verbands insgesamt, `k` davon im
/// betrachteten Topf). Fuer AAA gilt `m = 7` und `k = 4`, also `11 > 9`: Der
/// Widerspruch steht schon nach den ersten Kanten fest, statt erst durch die
/// Enumeration von 33_317 Zweigen bewiesen werden zu muessen.
private let unsolvableExpectedNodes: Int = 5

/// Grosszuegiges, aber endliches Knotenbudget fuer die Unloesbarkeits-Tests.
///
/// Der Wert liegt um Groessenordnungen ueber dem Bedarf und klar unterhalb der
/// Voreinstellung von zwei Millionen. Damit trennt er die beiden Abbruchgruende
/// sauber: Wer hier `searchBudgetExceeded` statt `unsolvable` sieht, hat einen
/// Suchaufwand, der nicht mehr zum Fixture passt.
private let unsolvableNodeBudget: Int = 100_000

// MARK: - Tests

@Suite("Unloesbare Eingaben und Suchbudget")
struct UnsolvableInputTests {

    // MARK: Das Fixture kommt an der Vorpruefung vorbei

    @Test("Das unloesbare Feld besteht die Vorab-Validierung")
    func unloesbaresFeldBestehtVorpruefung() throws {
        // Das ist der eigentliche Punkt dieses Fixtures: Nur weil die billigen
        // Schranken es durchlassen, pruefen die Tests darunter wirklich den
        // Backtracking-Pfad und nicht bloss `InputValidation`.
        try InputValidation.validate(teams: unsolvableFeld)
    }

    @Test("Das unloesbare Feld liegt genau auf den Schranken der Vorpruefung")
    func unloesbaresFeldLiegtAufDenSchranken() {
        #expect(unsolvableFeld.count == 36)
        #expect(InputValidation.potCounts(of: unsolvableFeld) == [9, 9, 9, 9])

        // AAA und BBB liegen mit sieben Teams genau auf der Gesamtschranke und
        // mit vier Teams in Topf 1 genau auf der Topfschranke. Verschiebt eine
        // spaetere Aenderung eine dieser Zahlen, prueft das Fixture nicht mehr,
        // was es pruefen soll - deshalb sind die Zaehler hier festgenagelt.
        #expect(InputValidation.potCounts(of: Association("AAA"), in: unsolvableFeld) == [4, 3, 0, 0])
        #expect(InputValidation.potCounts(of: Association("BBB"), in: unsolvableFeld) == [4, 3, 0, 0])
        #expect(InputValidation.potCounts(of: Association("CCC"), in: unsolvableFeld) == [1, 0, 0, 0])
    }

    // MARK: Unloesbarkeit

    @Test("Das beweisbar unloesbare Feld meldet unsolvable", .timeLimit(.minutes(1)))
    func unloesbaresFeldMeldetUnsolvable() {
        let engine = DrawEngine(configuration: .init(maxSearchNodes: unsolvableNodeBudget))
        #expect(throws: DrawError.unsolvable) {
            try engine.draw(teams: unsolvableFeld, seed: 1)
        }
    }

    @Test(
        "Die Unloesbarkeit haengt nicht am Seed",
        .timeLimit(.minutes(1)),
        arguments: unsolvableSeeds
    )
    func unloesbarkeitIstSeedUnabhaengig(seed: UInt64) {
        let engine = DrawEngine(configuration: .init(maxSearchNodes: unsolvableNodeBudget))
        #expect(throws: DrawError.unsolvable) {
            try engine.draw(teams: unsolvableFeld, seed: seed)
        }
    }

    @Test("Die Unloesbarkeit haengt nicht an der Eingabereihenfolge", .timeLimit(.minutes(1)))
    func unloesbarkeitIstReihenfolgeUnabhaengig() {
        // Umgedrehte Eingabe: Der `DrawContext` sortiert kanonisch, am Ausgang
        // darf sich dadurch nichts aendern.
        let engine = DrawEngine(configuration: .init(maxSearchNodes: unsolvableNodeBudget))
        #expect(throws: DrawError.unsolvable) {
            try engine.draw(teams: unsolvableFeld.reversed(), seed: 1)
        }
    }

    // MARK: Abgrenzung der beiden Abbruchgruende

    @Test("Mit dem voreingestellten Budget kommt unsolvable, nicht searchBudgetExceeded", .timeLimit(.minutes(1)))
    func unsolvableIstKeinBudgetAbbruch() {
        // Die Voreinstellung von zwei Millionen Knoten liegt um Groessenordnungen
        // ueber dem gemessenen Aufwand. `searchBudgetExceeded` waere hier also
        // nicht "knapp danebengegangen", sondern ein anderer Fehler.
        let engine = DrawEngine()
        do {
            _ = try engine.draw(teams: unsolvableFeld, seed: 7)
            Issue.record("Erwartet war ein Abbruch wegen Unloesbarkeit")
        } catch {
            if case .searchBudgetExceeded(let knoten) = error {
                Issue.record("Budget nach \(knoten) Knoten aufgebraucht, statt Unloesbarkeit zu erkennen")
                return
            }
            #expect(error == .unsolvable, "Falscher Fehler: \(error)")
        }
    }

    @Test("Ein Knoten unter dem Bedarf kippt unsolvable in searchBudgetExceeded", .timeLimit(.minutes(1)))
    func budgetGrenzeTrenntDieBeidenFaelle() {
        // Die scharfe Grenze zwischen den beiden Fehlerfaellen, und zugleich das
        // Mass fuer den Suchaufwand: Mit einem Knoten weniger als noetig bricht
        // dieselbe Eingabe wegen des Budgets ab, mit genau dem Bedarf laeuft der
        // Widerspruchsbeweis durch. Steigt der Aufwand durch eine Aenderung an
        // den Forward-Checks, schlaegt dieser Test als Erster an.
        let knappesBudget = DrawEngine(configuration: .init(maxSearchNodes: unsolvableExpectedNodes - 1))
        do {
            _ = try knappesBudget.draw(teams: unsolvableFeld, seed: 1)
            Issue.record("Erwartet war ein Abbruch wegen aufgebrauchten Budgets")
        } catch {
            guard case .searchBudgetExceeded(let knoten) = error else {
                Issue.record("Falscher Fehler: \(error)")
                return
            }
            // Abgebrochen wird beim ersten Knoten oberhalb des Budgets.
            #expect(knoten == unsolvableExpectedNodes)
        }

        let genauesBudget = DrawEngine(configuration: .init(maxSearchNodes: unsolvableExpectedNodes))
        #expect(throws: DrawError.unsolvable) {
            try genauesBudget.draw(teams: unsolvableFeld, seed: 1)
        }
    }

    // MARK: Suchbudget bei gueltiger Eingabe

    @Test("Ein winziges Knotenbudget bricht auch eine loesbare Auslosung ab")
    func winzigesBudgetBrichtAb() {
        let engine = DrawEngine(configuration: .init(maxSearchNodes: 10))
        do {
            _ = try engine.draw(teams: Fixtures.realistic36, seed: 1)
            Issue.record("Erwartet war ein Abbruch wegen aufgebrauchten Budgets")
        } catch {
            guard case .searchBudgetExceeded(let knoten) = error else {
                Issue.record("Falscher Fehler: \(error)")
                return
            }
            #expect(knoten > 0)
            // Abgebrochen wird beim ersten Knoten oberhalb des Budgets, der
            // Zaehler steht also genau auf `maxSearchNodes + 1`.
            #expect(knoten == 11)
        }
    }

    @Test("Dasselbe Feld laeuft mit ausreichendem Budget durch")
    func gueltigesFeldLaeuftDurch() throws {
        // Gegenprobe zum Test darueber: gleiche Eingabe, nur ein groesseres
        // Budget. Damit ist belegt, dass der Abbruch dort an der Konfiguration
        // lag und nicht am Feld.
        let ergebnis = try DrawEngine().draw(teams: Fixtures.realistic36, seed: 1)
        #expect(ergebnis.matches.count == 144)
        #expect(DrawValidator.violations(matches: ergebnis.matches, teams: ergebnis.teams).isEmpty)
    }

    // MARK: Kontrastgruppe - Ablehnung schon vor der Suche

    @Test("Acht Teams desselben Verbands scheitern bereits an der Vorpruefung")
    func achtTeamsEinesVerbandsScheiternFrueh() {
        #expect(throws: unsolvableEarlyRejectError) {
            try DrawEngine().draw(teams: unsolvableEarlyRejectFeld, seed: 1)
        }
    }

    @Test("Die Kontrastgruppe erreicht die Suche gar nicht")
    func kontrastgruppeErreichtDieSucheNicht() {
        // Ein Budget von einem einzigen Knoten wuerde jede echte Suche sofort
        // abbrechen. Dass trotzdem der Verbandsfehler kommt, zeigt: Die
        // Vorpruefung greift vorher. Die beiden Wege in die Unloesbarkeit -
        // billige Schranke und Widerspruchsbeweis - sind sauber getrennt.
        let engine = DrawEngine(configuration: .init(maxSearchNodes: 1))
        #expect(throws: unsolvableEarlyRejectError) {
            try engine.draw(teams: unsolvableEarlyRejectFeld, seed: 1)
        }
    }
}
