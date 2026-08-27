// OpponentRow.swift

import SwiftUI

struct OpponentRow: View {

    let opponent: ScheduledOpponent

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            VenueBadge(venue: opponent.venue, tint: Tokens.potColor(opponent.fromPot))

            Text(opponent.team.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: Tokens.Spacing.small)

            Text(opponent.team.association.id)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(.quaternary.opacity(0.5)))
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(opponent.team.name), \(opponent.venue.accessibilityLabel), aus Topf \(opponent.fromPot)"
        )
    }
}
