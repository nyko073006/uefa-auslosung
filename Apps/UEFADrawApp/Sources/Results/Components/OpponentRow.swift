// OpponentRow.swift

import SwiftUI

struct OpponentRow: View {

    let opponent: ScheduledOpponent

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            Image(systemName: opponent.venue.symbolName)
                .font(.caption)
                .frame(width: 18)
                .foregroundStyle(Tokens.potColor(opponent.fromPot))

            Text(opponent.team.name)
                .font(.subheadline)

            Spacer(minLength: Tokens.Spacing.small)

            Text(opponent.team.association.id)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("T\(opponent.fromPot)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Tokens.potColor(opponent.fromPot))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(opponent.team.name), \(opponent.venue.accessibilityLabel), Topf \(opponent.fromPot)"
        )
    }
}
