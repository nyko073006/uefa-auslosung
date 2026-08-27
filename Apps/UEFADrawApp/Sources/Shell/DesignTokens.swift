// DesignTokens.swift
//
// Zentrale Darstellungswerte. Haelt die Views schlank und die Optik konsistent.
// Adaptive Grids statt fester Breiten - dadurch traegt das iPhone-Layout das iPad mit.
//
// Hinweis zur Sprache: Kommentare und Bezeichner bleiben ASCII (siehe AGENTS.md),
// sichtbare Texte in der App verwenden echte Umlaute.

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
        static let card: CGFloat = 16
        static let chip: CGFloat = 10
        static let ball: CGFloat = 88
    }

    // MARK: - Bewegung

    /// Dauern bleiben unter 300 ms, damit die Bedienung reaktionsschnell wirkt.
    /// Nur die Enthuellung selbst darf etwas laenger sein - sie ist die Inszenierung.
    enum Motion {
        /// Eintritt und Austritt: startet schnell, wirkt sofort.
        static let enter = Animation.spring(duration: 0.34, bounce: 0.18)
        /// Bewegung auf dem Bildschirm.
        static let move = Animation.spring(duration: 0.28, bounce: 0.10)
        /// Reine Zustands- und Farbwechsel.
        static let state = Animation.easeOut(duration: 0.22)
        /// Druckfeedback.
        static let press = Animation.easeOut(duration: 0.16)
        /// Der Moment, in dem eine Kugel gezogen wird - darf tragen.
        static let ball = Animation.spring(duration: 0.46, bounce: 0.24)

        /// Reduzierte Bewegung heisst weniger und sanfter, nicht gar nichts:
        /// Deckkraft bleibt, Verschiebung faellt weg.
        static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
            reduceMotion ? .easeOut(duration: 0.18) : animation
        }

        /// Gestaffelte Verzoegerung fuer Listen. Kurz halten, sonst wirkt es traege.
        static func stagger(_ index: Int, step: Double = 0.045, cap: Double = 0.27) -> Double {
            min(Double(index) * step, cap)
        }
    }

    // MARK: - Farben

    /// Farbe je Lostopf. Toepfe sind 1-basiert.
    static func potColor(_ potIndex: Int) -> Color {
        switch potIndex {
        case 1: Color(red: 0.35, green: 0.36, blue: 0.90)
        case 2: Color(red: 0.10, green: 0.62, blue: 0.64)
        case 3: Color(red: 0.90, green: 0.52, blue: 0.16)
        case 4: Color(red: 0.83, green: 0.28, blue: 0.50)
        default: .gray
        }
    }

    static func potGradient(_ potIndex: Int) -> LinearGradient {
        let base = potColor(potIndex)
        return LinearGradient(
            colors: [base.opacity(0.95), base.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Flaechiger Hintergrund fuer Karten in Topf-Farbe.
    static func potSurface(_ potIndex: Int, emphasis: Double = 0.12) -> LinearGradient {
        let base = potColor(potIndex)
        return LinearGradient(
            colors: [base.opacity(emphasis + 0.05), base.opacity(emphasis * 0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Raster

    /// Gegner-Raster: zwei Spalten auf dem iPhone, mehr sobald Platz da ist.
    static let opponentGrid = [
        GridItem(.adaptive(minimum: 152, maximum: 260), spacing: Spacing.small)
    ]

    static let potStackGrid = [
        GridItem(.adaptive(minimum: 78, maximum: 170), spacing: Spacing.small)
    ]
}

// MARK: - Druckfeedback

/// Gibt jedem Druck eine sofortige, spuerbare Antwort. Bewusst subtil (0,97).
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Tokens.Motion.press, value: configuration.isPressed)
    }
}

extension View {

    /// Eintritt niemals aus dem Nichts: nichts in der echten Welt erscheint aus
    /// Groesse null. Start bei 0,94 plus Deckkraft wirkt natuerlich.
    func revealTransition(reduceMotion: Bool) -> some View {
        transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                    removal: .opacity
                )
        )
    }
}
