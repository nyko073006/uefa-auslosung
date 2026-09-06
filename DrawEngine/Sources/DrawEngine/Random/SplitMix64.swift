/// Deterministischer Pseudo-Zufallsgenerator nach dem SplitMix64-Verfahren.
///
/// Die Auslosung muss bei gleichem Seed exakt reproduzierbar sein. Deshalb
/// verwenden wir einen eigenen Generator statt `SystemRandomNumberGenerator`:
/// nur so ist die Zahlenfolge ueber Prozesslaeufe, Plattformen und
/// Swift-Versionen hinweg stabil.
///
/// Der Algorithmus ist bewusst simpel und vollstaendig hier abgebildet, damit
/// jede Aenderung sofort in den Regressions-Pins der Tests auffaellt.
public struct SplitMix64: RandomNumberGenerator, Sendable {

    /// Interner Zustand. Lesbar fuer Diagnose und Snapshots, aber nur ueber
    /// `next()` veraenderbar, damit die Folge nicht von aussen manipuliert wird.
    public private(set) var state: UInt64

    /// Erzeugt einen Generator fuer den angegebenen Seed.
    /// Gleicher Seed bedeutet immer die exakt gleiche Zahlenfolge.
    public init(seed: UInt64) {
        state = seed
    }

    /// Liefert den naechsten 64-Bit-Zufallswert.
    ///
    /// Alle Rechnungen laufen bewusst mit den ueberlauf-toleranten Operatoren
    /// `&+` und `&*`. Die normalen Operatoren wuerden in Debug-Builds bei
    /// Ueberlauf abbrechen, obwohl der Ueberlauf hier Teil des Verfahrens ist.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Unbiased Ziehung aus 0..<upperBound per Rejection-Sampling.
    /// Bewusst NICHT next(upperBound:) genannt: die Stdlib-Variante ist ein
    /// Implementierungsdetail ohne Stabilitaetsgarantie ueber Swift-Versionen.
    ///
    /// Ein simples `next() % upperBound` waere verzerrt, weil sich der
    /// 64-Bit-Wertebereich in der Regel nicht glatt durch `upperBound` teilen
    /// laesst. Wir verwerfen daher den unteren Rest-Block: alles unterhalb von
    /// `threshold` wird neu gezogen, der verbleibende Bereich ist ein exaktes
    /// Vielfaches von `upperBound` und damit gleichverteilt.
    ///
    /// - Parameter upperBound: Obere, ausgeschlossene Grenze. Muss groesser 0 sein.
    /// - Returns: Ein gleichverteilter Wert aus 0..<upperBound.
    public mutating func uniform(upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0, "upperBound muss groesser als 0 sein")
        // Nur ein moegliches Ergebnis: kein Zufallswert noetig, der Zustand
        // bleibt bewusst unveraendert.
        if upperBound == 1 { return 0 }
        // `0 &- upperBound` ist 2^64 - upperBound in Modulo-Arithmetik.
        let threshold = (0 &- upperBound) % upperBound
        var r = next()
        while r < threshold {
            r = next()
        }
        return r % upperBound
    }

    /// Bequemlichkeits-Variante fuer Int-Grenzen, etwa fuer Array-Indizes.
    ///
    /// - Parameter upperBound: Obere, ausgeschlossene Grenze. Muss groesser 0 sein.
    /// - Returns: Ein gleichverteilter Wert aus 0..<upperBound.
    public mutating func uniform(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound muss groesser als 0 sein")
        return Int(uniform(upperBound: UInt64(upperBound)))
    }
}
