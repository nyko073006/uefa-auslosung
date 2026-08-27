// PotStackView.swift
//
// Die vier Lostoepfe mit Restanzahl. Der gerade geoeffnete Topf ist hervorgehoben.

import SwiftUI

struct PotStackView: View {

    let pots: [Pot]
    let remainingByPot: [Int: Int]
    let openPot: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LazyVGrid(columns: Tokens.evenColumns(pots.count), spacing: Tokens.Spacing.small) {
            ForEach(pots) { pot in
                potTile(pot)
            }
        }
    }

    private func potTile(_ pot: Pot) -> some View {
        let total = pot.teams.count
        let remaining = remainingByPot[pot.id] ?? total
        let isOpen = openPot == pot.id
        let drawn = total - remaining

        return VStack(spacing: Tokens.Spacing.tight) {
            Text("Topf \(pot.id)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isOpen ? .primary : .secondary)

            Text("\(remaining)")
                .font(.title2.monospacedDigit().weight(.bold))
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(Tokens.potColor(pot.id))

            // Fuellstand statt nur einer Zahl - auf einen Blick erfassbar.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(Tokens.potGradient(pot.id))
                        .frame(width: proxy.size.width * fraction(drawn: drawn, total: total))
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.small)
        .padding(.horizontal, Tokens.Spacing.small)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .fill(Tokens.potSurface(pot.id, emphasis: isOpen ? 0.22 : 0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .strokeBorder(
                    Tokens.potColor(pot.id).opacity(isOpen ? 0.85 : 0),
                    lineWidth: 1.5
                )
        }
        .scaleEffect(isOpen && !reduceMotion ? 1.03 : 1)
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.move), value: isOpen)
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.state), value: remaining)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Topf \(pot.id), \(remaining) von \(total) Teams offen")
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    private func fraction(drawn: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(drawn) / CGFloat(total)
    }
}
