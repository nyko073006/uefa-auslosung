// OpponentSlotGrid.swift
//
// Die Gegner-Plaetze des laufenden Teams, gruppiert nach Herkunftstopf.
// Leere Plaetze bleiben sichtbar, damit der Fortschritt lesbar ist.

import SwiftUI

struct OpponentSlotGrid: View {

    let pots: [Int]
    let slotsPerPot: Int
    let revealed: [(opponent: RevealedOpponent, team: Team)]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
            ForEach(pots, id: \.self) { pot in
                let entries = revealed.filter { $0.opponent.fromPot == pot }

                VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                    header(pot: pot, filled: entries.count)

                    LazyVGrid(columns: Tokens.evenColumns(slotsPerPot), spacing: Tokens.Spacing.small) {
                        ForEach(0..<slotsPerPot, id: \.self) { index in
                            if index < entries.count {
                                filledSlot(entries[index])
                                    .revealTransition(reduceMotion: reduceMotion)
                            } else {
                                emptySlot(pot: pot)
                            }
                        }
                    }
                }
            }
        }
        .animation(
            Tokens.Motion.respecting(reduceMotion, Tokens.Motion.enter),
            value: revealed.count
        )
    }

    private func header(pot: Int, filled: Int) -> some View {
        HStack(spacing: Tokens.Spacing.small) {
            Capsule()
                .fill(Tokens.potGradient(pot))
                .frame(width: 14, height: 4)

            Text("Aus Topf \(pot)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(filled)/\(slotsPerPot)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
        }
    }

    private func filledSlot(_ entry: (opponent: RevealedOpponent, team: Team)) -> some View {
        HStack(spacing: Tokens.Spacing.small) {
            VenueBadge(venue: entry.opponent.venue, tint: Tokens.potColor(entry.opponent.fromPot))

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.team.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(entry.team.association.id)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.small)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .fill(Tokens.potSurface(entry.opponent.fromPot, emphasis: 0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .strokeBorder(Tokens.potColor(entry.opponent.fromPot).opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.team.name), \(entry.opponent.venue.accessibilityLabel), aus Topf \(entry.opponent.fromPot)"
        )
    }

    private func emptySlot(pot: Int) -> some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
            .strokeBorder(
                Tokens.potColor(pot).opacity(0.22),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
            .frame(height: 48)
            .accessibilityHidden(true)
    }
}

/// Heim oder Auswaerts als kompaktes Abzeichen.
struct VenueBadge: View {

    let venue: Venue
    let tint: Color

    var body: some View {
        Image(systemName: venue.symbolName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(venue == .home ? .white : tint)
            .frame(width: 24, height: 24)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(venue == .home ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.15)))
            }
            .accessibilityHidden(true)
    }
}
