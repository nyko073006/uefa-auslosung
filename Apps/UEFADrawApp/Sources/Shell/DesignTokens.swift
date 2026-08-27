// DesignTokens.swift
//
// Zentrale Darstellungswerte. Haelt die Views schlank und die Optik konsistent.
// Adaptive Grids statt fester Breiten - dadurch traegt iPhone-Layout das iPad mit.

import SwiftUI

enum Tokens {

    enum Spacing {
        static let tight: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
        static let section: CGFloat = 28
    }

    enum Radius {
        static let card: CGFloat = 14
        static let chip: CGFloat = 8
    }

    enum Motion {
        static let reveal = Animation.spring(response: 0.42, dampingFraction: 0.78)
        static let swap = Animation.easeInOut(duration: 0.25)
        static let banner = Animation.easeOut(duration: 0.2)
    }

    /// Farbe je Lostopf. Toepfe sind 1-basiert.
    static func potColor(_ potIndex: Int) -> Color {
        switch potIndex {
        case 1: .indigo
        case 2: .teal
        case 3: .orange
        case 4: .pink
        default: .gray
        }
    }

    /// Gegner-Raster: zwei Spalten auf dem iPhone, mehr sobald Platz da ist.
    static let opponentGrid = [
        GridItem(.adaptive(minimum: 150, maximum: 260), spacing: Spacing.small)
    ]

    static let potStackGrid = [
        GridItem(.adaptive(minimum: 78, maximum: 160), spacing: Spacing.small)
    ]
}
