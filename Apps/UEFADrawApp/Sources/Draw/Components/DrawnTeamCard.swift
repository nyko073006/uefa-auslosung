// DrawnTeamCard.swift
//
// Die Karte des gerade gezogenen Teams - der Spannungsmoment der Auslosung.

import SwiftUI

struct DrawnTeamCard: View {

    let team: Team?
    let revealedCount: Int
    let expectedCount: Int

    var body: some View {
        VStack(spacing: Tokens.Spacing.small) {
            if let team {
                Text(team.association.name.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(team.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                HStack(spacing: Tokens.Spacing.small) {
                    Label("Topf \(team.potIndex)", systemImage: "tray.fill")
                    Text("\(revealedCount) von \(expectedCount) Gegnern")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Warte auf die naechste Kugel")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Spacing.large)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .fill(Tokens.potColor(team?.potIndex ?? 0).opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.card)
                .strokeBorder(Tokens.potColor(team?.potIndex ?? 0).opacity(0.5), lineWidth: 1)
        }
        .animation(Tokens.Motion.reveal, value: team)
        .accessibilityElement(children: .combine)
    }
}
