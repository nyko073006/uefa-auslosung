// TeamLogoView.swift
//
// Vereinswappen aus dem Asset-Katalog, mit Rueckfall auf das Verbandskuerzel.
//
// Die Wappen aus Resources/Design sind aus einer Montage geschnitten und nur
// rund 71 px hoch. Sie sind deshalb als 3x hinterlegt und tragen bis etwa
// 28 pt sauber. Groesser wird nur die Flaeche - nicht das Bild.

import SwiftUI

struct TeamLogoView: View {

    let team: Team
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Text(team.association.id)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(Tokens.Brand.textSecondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Nur zeichnen, wenn das Wappen wirklich vorliegt - sonst faellt die
    /// Ansicht auf das Kuerzel zurueck statt auf eine leere Flaeche.
    private var assetName: String? {
        guard let logoName = team.logoName else { return nil }
        let name = "TeamLogos/\(logoName)"
        #if canImport(UIKit)
        return UIImage(named: name) == nil ? nil : name
        #else
        return name
        #endif
    }
}
