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
                .frame(width: 16, height: 4)

            Text("Aus Topf \(pot)")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Tokens.potColor(pot))

            Spacer()

            Text("\(filled)/\(slotsPerPot)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Tokens.Brand.textTertiary)
                .contentTransition(.numericText())
        }
    }

    private func filledSlot(_ entry: (opponent: RevealedOpponent, team: Team)) -> some View {
        let tint = Tokens.potColor(entry.opponent.fromPot)

        return HStack(spacing: Tokens.Spacing.small) {
            TeamLogoView(team: entry.team, size: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.team.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(entry.team.association.id)
                    .font(.caption2)
                    .foregroundStyle(Tokens.Brand.textSecondary)
            }

            Spacer(minLength: 0)

            VenueBadge(venue: entry.opponent.venue, tint: tint)
        }
        .padding(Tokens.Spacing.small)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .fill(Tokens.potSurface(entry.opponent.fromPot, emphasis: 0.16))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .strokeBorder(tint.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.team.name), \(entry.opponent.venue.accessibilityLabel), aus Topf \(entry.opponent.fromPot)"
        )
    }

    private func emptySlot(pot: Int) -> some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
            .strokeBorder(
                Tokens.potColor(pot).opacity(0.28),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])
            )
            .frame(height: 50)
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
            .foregroundStyle(venue == .home ? Tokens.Brand.deep : tint)
            .frame(width: 24, height: 24)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(venue == .home ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.18)))
            }
            .accessibilityHidden(true)
    }
}
