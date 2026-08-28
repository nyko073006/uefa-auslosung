extension Array {

    /// Deterministischer Fisher-Yates rueckwaerts. Eigene Implementierung, weil
    /// Array.shuffled(using:) von der Stdlib nicht versionsstabil garantiert ist.
    ///
    /// Mischt in-place. Bei leeren und einelementigen Arrays passiert nichts,
    /// weil die Schleife dann gar nicht erst laeuft.
    ///
    /// - Parameter rng: Der Generator, dessen Zustand dabei fortschreitet.
    mutating func deterministicShuffle(using rng: inout SplitMix64) {
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = rng.uniform(upperBound: i + 1)
            swapAt(i, j)
        }
    }

    /// Liefert eine gemischte Kopie, ohne das Original zu veraendern.
    ///
    /// - Parameter rng: Der Generator, dessen Zustand dabei fortschreitet.
    /// - Returns: Eine Permutation des Arrays.
    func deterministicallyShuffled(using rng: inout SplitMix64) -> Self {
        var kopie = self
        kopie.deterministicShuffle(using: &rng)
        return kopie
    }
}
