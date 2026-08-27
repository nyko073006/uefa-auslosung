// OpponentSlotGrid.swift
//
// Die acht Gegner-Plaetze des laufenden Teams, gruppiert nach Herkunftstopf.
// Leere Plaetze bleiben sichtbar, damit der Fortschritt lesbar ist.

import SwiftUI

struct OpponentSlotGrid: View {

    let pots: [Int]
    let slotsPerPot: Int
    let revealed: [(opponent: RevealedOpponent, team: Team)]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            ForEach(pots, id: \.self) { pot in
                let entries = revealed.filter { $0.opponent.fromPot == pot }

                VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                    HStack(spacing: Tokens.Spacing.tight) {
                        Circle()
                            .fill(Tokens.potColor(pot))
                            .frame(width: 8, height: 8)
                        Text("Aus Topf \(pot)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: Tokens.opponentGrid, spacing: Tokens.Spacing.small) {
                        ForEach(0..<slotsPerPot, id: \.self) { index in
                            if index < entries.count {
                                filledSlot(entries[index])
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                emptySlot(pot: pot)
                            }
                        }
                    }
                }
            }
        }
        .animation(Tokens.Motion.reveal, value: revealed.count)
    }

    private func filledSlot(_ entry: (opponent: RevealedOpponent, team: Team)) -> some View {
        HStack(spacing: Tokens.Spacing.small) {
            Image(systemName: entry.opponent.venue.symbolName)
                .font(.caption)
                .foregroundStyle(Tokens.potColor(entry.opponent.fromPot))

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.team.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(entry.team.association.id)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Spacing.small)
        .padding(.vertical, Tokens.Spacing.small)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip)
                .fill(Tokens.potColor(entry.opponent.fromPot).opacity(0.14))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.team.name), \(entry.opponent.venue.accessibilityLabel), aus Topf \(entry.opponent.fromPot)"
        )
    }

    private func emptySlot(pot: Int) -> some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.chip)
            .strokeBorder(
                Tokens.potColor(pot).opacity(0.25),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
            .frame(height: 44)
            .accessibilityHidden(true)
    }
}
