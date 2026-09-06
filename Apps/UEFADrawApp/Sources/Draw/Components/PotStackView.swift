// PotStackView.swift
//
// Die vier Lostoepfe mit Restanzahl. Der gerade geoeffnete Topf leuchtet.

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
        let tint = Tokens.potColor(pot.id)

        return VStack(spacing: Tokens.Spacing.tight) {
            Text("TOPF \(pot.id)")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(isOpen ? tint : Tokens.Brand.textSecondary)

            Text("\(remaining)")
                .font(.title2.monospacedDigit().weight(.bold))
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(.white)

            // Fuellstand statt nur einer Zahl - auf einen Blick erfassbar.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.Brand.hairline)
                    Capsule()
                        .fill(Tokens.potGradient(pot.id))
                        .frame(width: proxy.size.width * fraction(drawn: total - remaining, total: total))
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.small)
        .padding(.horizontal, Tokens.Spacing.small)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .fill(isOpen ? AnyShapeStyle(Tokens.potSurface(pot.id, emphasis: 0.22))
                             : AnyShapeStyle(Tokens.Brand.surface))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .strokeBorder(
                    isOpen ? tint.opacity(0.9) : Tokens.Brand.hairline,
                    lineWidth: isOpen ? 1.5 : 1
                )
        }
        .shadow(color: tint.opacity(isOpen ? 0.45 : 0), radius: 12)
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
