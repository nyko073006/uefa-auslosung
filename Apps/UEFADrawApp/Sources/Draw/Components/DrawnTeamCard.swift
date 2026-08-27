// DrawnTeamCard.swift
//
// Die Kugel des gerade gezogenen Teams - der Spannungsmoment der Auslosung.

import SwiftUI

struct DrawnTeamCard: View {

    let team: Team?
    let revealedCount: Int
    let expectedCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Tokens.Spacing.medium) {
            ball

            if let team {
                VStack(spacing: Tokens.Spacing.tight) {
                    Text(team.name)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text(team.association.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .id(team.id)
                .revealTransition(reduceMotion: reduceMotion)

                progressPips
            } else {
                Text("Warte auf die nächste Kugel")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.large)
        .padding(.horizontal, Tokens.Spacing.medium)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .fill(Tokens.potSurface(team?.potIndex ?? 0))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .strokeBorder(
                    Tokens.potColor(team?.potIndex ?? 0).opacity(0.35),
                    lineWidth: 1
                )
        }
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.ball), value: team)
    }

    /// Die Loskugel. Beim Teamwechsel wird sie neu aufgebaut, damit der
    /// Uebergang als eigener Moment lesbar ist.
    private var ball: some View {
        ZStack {
            Circle()
                .fill(Tokens.potGradient(team?.potIndex ?? 0))
                .frame(width: Tokens.Radius.ball, height: Tokens.Radius.ball)
                .overlay {
                    // Angedeutetes Glanzlicht - gibt der Kugel Koerper.
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                }
                .shadow(
                    color: Tokens.potColor(team?.potIndex ?? 0).opacity(0.35),
                    radius: 12, y: 6
                )

            if let team {
                Text(team.association.id)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(radius: 1, y: 1)
                    .id(team.id)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
            } else {
                Image(systemName: "questionmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .accessibilityHidden(true)
    }

    /// Fortschritt als Punktreihe statt als Zahl - schneller erfassbar.
    private var progressPips: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            ForEach(0..<max(expectedCount, 0), id: \.self) { index in
                Capsule()
                    .fill(
                        index < revealedCount
                            ? AnyShapeStyle(Tokens.potColor(team?.potIndex ?? 0))
                            : AnyShapeStyle(.quaternary)
                    )
                    .frame(width: index < revealedCount ? 14 : 8, height: 4)
            }
        }
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.move), value: revealedCount)
        .accessibilityElement()
        .accessibilityLabel("\(revealedCount) von \(expectedCount) Gegnern gezogen")
    }
}
