// DrawnTeamCard.swift
//
// Die Kugel des gerade gezogenen Teams - der Spannungsmoment der Auslosung.
// Das Wappen sitzt im Zentrum auf ruhiger Flaeche, wie in draw-style.md gefordert.

import SwiftUI

struct DrawnTeamCard: View {

    let team: Team?
    let revealedCount: Int
    let expectedCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        Tokens.potColor(team?.potIndex ?? 0)
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.medium) {
            ball

            if let team {
                VStack(spacing: Tokens.Spacing.tight) {
                    Text(team.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text(team.association.name.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(tint)
                }
                .id(team.id)
                .revealTransition(reduceMotion: reduceMotion)

                progressPips
            } else {
                Text("Warte auf die nächste Kugel")
                    .font(.headline)
                    .foregroundStyle(Tokens.Brand.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.large)
        .padding(.horizontal, Tokens.Spacing.medium)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .fill(Tokens.Brand.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .strokeBorder(tint.opacity(0.4), lineWidth: 1)
        }
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.ball), value: team)
    }

    /// Die Loskugel: dunkle Scheibe, Neonring, Wappen in der Mitte.
    private var ball: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.30), tint.opacity(0.05)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: Tokens.Radius.ball
                    )
                )

            Circle()
                .strokeBorder(tint.opacity(0.85), lineWidth: 2)

            // Zweiter, weiterer Ring - greift das Linienmuster des Hintergrunds auf.
            Circle()
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                .padding(-9)

            if let team {
                TeamLogoView(team: team, size: 54)
                    .id(team.id)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.7).combined(with: .opacity)
                    )
            } else {
                Image(systemName: "questionmark")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Tokens.Brand.textTertiary)
            }
        }
        .frame(width: Tokens.Radius.ball, height: Tokens.Radius.ball)
        .shadow(color: tint.opacity(0.45), radius: 18)
        .accessibilityHidden(true)
    }

    /// Fortschritt als Punktreihe statt als Zahl - schneller erfassbar.
    private var progressPips: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            ForEach(0..<max(expectedCount, 0), id: \.self) { index in
                Capsule()
                    .fill(index < revealedCount ? tint : Tokens.Brand.hairline)
                    .frame(width: index < revealedCount ? 16 : 8, height: 4)
            }
        }
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.move), value: revealedCount)
        .accessibilityElement()
        .accessibilityLabel("\(revealedCount) von \(expectedCount) Gegnern gezogen")
    }
}
