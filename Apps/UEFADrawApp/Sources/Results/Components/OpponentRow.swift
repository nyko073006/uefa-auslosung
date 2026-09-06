// OpponentRow.swift

import SwiftUI

struct OpponentRow: View {

    let opponent: ScheduledOpponent

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            TeamLogoView(team: opponent.team, size: 24)

            Text(opponent.team.name)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: Tokens.Spacing.small)

            Text(opponent.team.association.id)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Tokens.Brand.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Tokens.Brand.surface))

            VenueBadge(venue: opponent.venue, tint: Tokens.potColor(opponent.fromPot))
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(opponent.team.name), \(opponent.venue.accessibilityLabel), aus Topf \(opponent.fromPot)"
        )
    }
}
