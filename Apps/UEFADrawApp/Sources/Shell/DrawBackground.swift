// DrawBackground.swift
//
// Der Marken-Hintergrund: tiefes Blau mit geometrischem Linienmuster.
//
// draw-style.md nennt "geometrische und optische Linienmuster" und "runde,
// glatte Formen statt harter Kanten". Umgesetzt als konzentrische Boegen um
// einen Punkt oberhalb des Bildschirms - das laesst den oberen Bereich, wo
// die Ziehung stattfindet, wie eine ruhige Flaeche wirken.
//
// Bewusst statisch: der Hintergrund wird auf jedem Screen dauerhaft gesehen,
// eine Animation darin waere Ablenkung ohne Zweck.

import SwiftUI

struct DrawBackground: View {

    /// Akzentfarbe der Linien, folgt bei Bedarf dem gerade offenen Topf.
    var accent: Color = Tokens.Brand.cyan

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Tokens.Brand.mid, Tokens.Brand.deep],
                startPoint: .top,
                endPoint: .bottom
            )

            // Aufhellung hinter dem oberen Bereich, wo die Kugel liegt.
            RadialGradient(
                colors: [Tokens.Brand.lift.opacity(0.85), .clear],
                center: UnitPoint(x: 0.5, y: 0.02),
                startRadius: 0,
                endRadius: 520
            )

            arcs
        }
        .ignoresSafeArea()
    }

    private var arcs: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: -size.height * 0.10)
                let step = max(size.width, size.height) / 9

                for index in 1...10 {
                    let radius = step * CGFloat(index)
                    let path = Path(
                        ellipseIn: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                    )
                    // Aussen leiser: die Linien sollen den Inhalt tragen, nicht stoeren.
                    let fade = 1 - Double(index) / 12
                    context.stroke(
                        path,
                        with: .color(accent.opacity(0.10 * fade)),
                        lineWidth: index.isMultiple(of: 3) ? 1.4 : 0.7
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    DrawBackground()
}
