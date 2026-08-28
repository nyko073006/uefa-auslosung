import Testing
@testable import DrawEngine

@Suite("SplitMix64 und deterministischer Shuffle")
struct SplitMix64Tests {

    // MARK: - Bekannte Referenzwerte

    @Test("Erster Wert fuer Seed 0 entspricht dem Referenz-Testvektor")
    func bekannterErsterWert() {
        var rng = SplitMix64(seed: 0)
        #expect(rng.next() == 0xE220_A839_7B1D_CDAF)
    }

    /// Regressions-Pin, damit eine Aenderung am RNG sofort auffaellt.
    /// Die Werte stammen aus der Referenz-Implementierung von SplitMix64;
    /// der erste Wert ist der oeffentlich dokumentierte Testvektor fuer Seed 0.
    static let ersteFuenfWerteSeedNull: [UInt64] = [
        0xE220_A839_7B1D_CDAF,
        0x6E78_9E6A_A1B9_65F4,
        0x06C4_5D18_8009_454F,
        0xF88B_B8A8_724C_81EC,
        0x1B39_896A_51A8_749B,
    ]

    @Test("Erste fuenf Werte fuer Seed 0 bleiben unveraendert")
    func gepinnteWertefolge() {
        var rng = SplitMix64(seed: 0)
        let werte = (0..<5).map { _ in rng.next() }
        #expect(werte == Self.ersteFuenfWerteSeedNull)
    }

    // MARK: - Determinismus

    @Test("Gleicher Seed liefert 1000 identische Werte")
    func gleicherSeedGleicheFolge() {
        var a = SplitMix64(seed: 2025)
        var b = SplitMix64(seed: 2025)
        for schritt in 0..<1000 {
            let werteA = a.next()
            let werteB = b.next()
            #expect(werteA == werteB, "Abweichung bei Schritt \(schritt)")
        }
    }

    @Test("Verschiedene Seeds unterscheiden sich in den ersten 100 Werten")
    func verschiedeneSeedsUnterscheidenSich() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 2)
        var gefundenerUnterschied = false
        for _ in 0..<100 {
            if a.next() != b.next() {
                gefundenerUnterschied = true
            }
        }
        #expect(gefundenerUnterschied)
    }

    @Test("Der Zustand entspricht nach n Schritten dem eines frisch nachgezogenen Generators")
    func zustandIstReproduzierbar() {
        var a = SplitMix64(seed: 7)
        var b = SplitMix64(seed: 7)
        for _ in 0..<50 { _ = a.next() }
        for _ in 0..<50 { _ = b.next() }
        #expect(a.state == b.state)
    }

    // MARK: - uniform

    @Test("uniform bleibt immer innerhalb der Grenzen", arguments: [1, 2, 9, 36, 1000])
    func uniformHaeltGrenzenEin(upperBound: Int) {
        var rng = SplitMix64(seed: UInt64(upperBound) &* 31 &+ 17)
        for _ in 0..<10_000 {
            let wert = rng.uniform(upperBound: upperBound)
            #expect(wert >= 0)
            #expect(wert < upperBound)
            if upperBound == 1 {
                #expect(wert == 0)
            }
        }
    }

    @Test("uniform mit upperBound 1 liefert immer 0")
    func uniformMitEinsIstImmerNull() {
        var rng = SplitMix64(seed: 99)
        for _ in 0..<1_000 {
            #expect(rng.uniform(upperBound: 1) == 0)
        }
    }

    @Test("uniform verteilt grob gleichmaessig")
    func uniformVerteiltGrobGleichmaessig() {
        // Sehr lockere Schranke: bei 90000 Ziehungen auf 9 Werte sind rund
        // 10000 Treffer je Wert zu erwarten. Die Grenze von 9000 schlaegt nur
        // bei groben Bias-Fehlern an, nicht bei normaler Streuung.
        var rng = SplitMix64(seed: 4711)
        var trefferProWert = [Int](repeating: 0, count: 9)
        for _ in 0..<90_000 {
            trefferProWert[rng.uniform(upperBound: 9)] += 1
        }
        for wert in 0..<9 {
            #expect(trefferProWert[wert] >= 9_000, "Wert \(wert) nur \(trefferProWert[wert])-mal gezogen")
        }
        #expect(trefferProWert.reduce(0, +) == 90_000)
    }

    // MARK: - Shuffle

    /// Regressions-Pin, damit eine Aenderung am Shuffle sofort auffaellt.
    /// Ergebnis von Array(0..<10), gemischt mit SplitMix64(seed: 42).
    static let gepinnterShuffleSeed42: [Int] = [0, 9, 5, 8, 6, 4, 7, 2, 1, 3]

    @Test("Shuffle-Ergebnis fuer Seed 42 bleibt unveraendert")
    func gepinnterShuffle() {
        var rng = SplitMix64(seed: 42)
        let gemischt = Array(0..<10).deterministicallyShuffled(using: &rng)
        #expect(gemischt == Self.gepinnterShuffleSeed42)
    }

    @Test("Shuffle liefert eine Permutation des Originals")
    func shuffleIstPermutation() {
        let original = Array(0..<36)
        var rng = SplitMix64(seed: 123)
        let gemischt = original.deterministicallyShuffled(using: &rng)
        #expect(gemischt.count == original.count)
        #expect(gemischt.sorted() == original)
    }

    @Test("Gleicher Seed liefert das gleiche Shuffle-Ergebnis")
    func shuffleIstDeterministisch() {
        let original = Array(0..<36)
        var rngA = SplitMix64(seed: 555)
        var rngB = SplitMix64(seed: 555)
        #expect(
            original.deterministicallyShuffled(using: &rngA)
                == original.deterministicallyShuffled(using: &rngB)
        )
    }

    @Test("Leeres und einelementiges Array bleiben unveraendert")
    func shuffleAufKleinenArrays() {
        var rng = SplitMix64(seed: 8)
        let zustandVorher = rng.state

        let leer = [Int]().deterministicallyShuffled(using: &rng)
        #expect(leer.isEmpty)

        let einElement = [42].deterministicallyShuffled(using: &rng)
        #expect(einElement == [42])

        // Beide Faelle ziehen keinen Zufallswert, der Generator steht still.
        #expect(rng.state == zustandVorher)
    }

    @Test("deterministicShuffle mischt in-place identisch zur Kopier-Variante")
    func inPlaceEntsprichtKopie() {
        var inPlace = Array(0..<20)
        var rngA = SplitMix64(seed: 2024)
        inPlace.deterministicShuffle(using: &rngA)

        var rngB = SplitMix64(seed: 2024)
        let kopie = Array(0..<20).deterministicallyShuffled(using: &rngB)

        #expect(inPlace == kopie)
    }

    @Test("Ein nicht-trivialer Shuffle veraendert die Reihenfolge tatsaechlich")
    func shuffleVeraendertReihenfolge() {
        let original = Array(0..<36)
        var rng = SplitMix64(seed: 31337)
        let gemischt = original.deterministicallyShuffled(using: &rng)
        #expect(gemischt != original)
    }
}
