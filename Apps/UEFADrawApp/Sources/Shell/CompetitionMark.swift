// CompetitionMark.swift
//
// Die Wortmarke des Wettbewerbs aus Resources/Design.
//
// Als Vektor im Asset-Katalog hinterlegt und auf `template` gestellt, damit sie
// eingefaerbt werden kann - im Original ist sie dunkelblau und waere auf dem
// dunklen Grund unsichtbar.

import SwiftUI

struct CompetitionMark: View {

    var width: CGFloat = 180
    var tint: Color = .white

    /// Seitenverhaeltnis der Vorlage (128 x 58).
    private let aspect: CGFloat = 128.0 / 58.0

    var body: some View {
        Image("ChampionsLeagueLogo")
            .renderable(width: width, aspect: aspect)
            .foregroundStyle(tint)
            .accessibilityLabel("UEFA Champions League")
    }
}

private extension Image {
    func renderable(width: CGFloat, aspect: CGFloat) -> some View {
        self
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: width, height: width / aspect)
    }
}
