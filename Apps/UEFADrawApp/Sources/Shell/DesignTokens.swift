// DesignTokens.swift
//
// Zentrale Darstellungswerte nach der Vorgabe aus Resources/Design/draw-style.md:
// tiefes UEFA-Blau, Neon-Akzente, runde Formen, hoher Kontrast.
//
// Die App legt sich bewusst auf Dunkel fest ("dunkle UEFA-Inspiration statt
// generischer hellgrauer Screens"), deshalb sind die Farben gesetzt und nicht
// vom Systemschema abhaengig.
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
        static let card: CGFloat = 18
        static let chip: CGFloat = 12
        static let ball: CGFloat = 104
    }

    // MARK: - Markenfarben

    enum Brand {
        /// Grundtoene des Hintergrunds, von unten nach oben aufhellend.
        static let deep = Color(red: 0.016, green: 0.031, blue: 0.114)
        static let mid = Color(red: 0.035, green: 0.071, blue: 0.243)
        static let lift = Color(red: 0.071, green: 0.129, blue: 0.404)

        /// Neon-Akzente. Vier Farben, vier Toepfe.
        static let cyan = Color(red: 0.180, green: 0.898, blue: 0.996)
        static let magenta = Color(red: 0.976, green: 0.263, blue: 0.678)
        static let yellow = Color(red: 1.000, green: 0.827, blue: 0.267)
        static let green = Color(red: 0.290, green: 0.949, blue: 0.573)

        /// Flaechen und Linien auf dem dunklen Grund.
        static let surface = Color.white.opacity(0.065)
        static let surfaceRaised = Color.white.opacity(0.10)
        static let hairline = Color.white.opacity(0.14)
        static let textSecondary = Color.white.opacity(0.62)
        static let textTertiary = Color.white.opacity(0.38)
    }

    // MARK: - Bewegung

    /// Dauern bleiben unter 300 ms, damit die Bedienung reaktionsschnell wirkt.
    /// Nur die Enthuellung selbst darf etwas laenger sein - sie ist die Inszenierung.
    enum Motion {
        static let enter = Animation.spring(duration: 0.34, bounce: 0.18)
        static let move = Animation.spring(duration: 0.28, bounce: 0.10)
        static let state = Animation.easeOut(duration: 0.22)
        static let press = Animation.easeOut(duration: 0.16)
        /// Der Moment, in dem eine Kugel gezogen wird - darf tragen.
        static let ball = Animation.spring(duration: 0.46, bounce: 0.24)

        /// Reduzierte Bewegung heisst weniger und sanfter, nicht gar nichts:
        /// Deckkraft bleibt, Verschiebung faellt weg.
        static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
            reduceMotion ? .easeOut(duration: 0.18) : animation
        }
    }

    // MARK: - Toepfe

    /// Farbe je Lostopf. Toepfe sind 1-basiert.
    static func potColor(_ potIndex: Int) -> Color {
        switch potIndex {
        case 1: Brand.cyan
        case 2: Brand.magenta
        case 3: Brand.yellow
        case 4: Brand.green
        default: Brand.textTertiary
        }
    }

    static func potGradient(_ potIndex: Int) -> LinearGradient {
        let base = potColor(potIndex)
        return LinearGradient(
            colors: [base, base.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Dunkle Karte mit einem Hauch Topf-Farbe. Bewusst zurueckhaltend -
    /// das Neon soll auf Linien und Schrift liegen, nicht auf Flaechen.
    static func potSurface(_ potIndex: Int, emphasis: Double = 0.12) -> LinearGradient {
        let base = potColor(potIndex)
        return LinearGradient(
            colors: [base.opacity(emphasis), base.opacity(emphasis * 0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Raster

    /// Lesbare Maximalbreite. Ohne sie zieht der Inhalt auf dem iPad ueber die
    /// volle Breite auseinander und wirkt verloren.
    static let contentMaxWidth: CGFloat = 760

    /// Feste Spaltenzahl statt `.adaptive`: adaptive Raster deckeln bei `maximum`
    /// und lassen den Rest der Breite ungenutzt - auf dem iPad kleben die Kacheln
    /// dann am linken Rand. Gleichmaessig verteilte Spalten fuellen immer.
    static func evenColumns(_ count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: Spacing.small),
            count: max(count, 1)
        )
    }
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

// MARK: - Bausteine

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

    /// Dunkle Karte mit feiner Kontur - der Grundbaustein der Oberflaeche.
    func brandCard(
        cornerRadius: CGFloat = Tokens.Radius.card,
        tint: Color? = nil,
        strokeOpacity: Double = 1
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Tokens.Brand.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    (tint ?? Tokens.Brand.hairline).opacity(tint == nil ? 1 : 0.45 * strokeOpacity),
                    lineWidth: 1
                )
        }
    }

    /// Setzt den Marken-Hintergrund und blendet die Standardflaechen von
    /// Form und List aus, damit keine hellgrauen Systemscreens durchscheinen.
    func brandScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { DrawBackground() }
    }
}
