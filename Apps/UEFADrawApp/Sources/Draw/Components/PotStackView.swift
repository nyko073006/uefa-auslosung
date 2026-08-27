// PotStackView.swift
//
// Die vier Lostoepfe mit Restanzahl. Der gerade geoeffnete Topf ist hervorgehoben.

import SwiftUI

struct PotStackView: View {

    let pots: [Pot]
    let remainingByPot: [Int: Int]
    let openPot: Int?

    var body: some View {
        LazyVGrid(columns: Tokens.potStackGrid, spacing: Tokens.Spacing.small) {
            ForEach(pots) { pot in
                let remaining = remainingByPot[pot.id] ?? pot.teams.count
                let isOpen = openPot == pot.id

                VStack(spacing: Tokens.Spacing.tight) {
                    Text("Topf \(pot.id)")
                        .font(.caption.weight(.semibold))
                    Text("\(remaining)")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .contentTransition(.numericText())
                    Text("offen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Spacing.small)
                .background {
                    RoundedRectangle(cornerRadius: Tokens.Radius.card)
                        .fill(Tokens.potColor(pot.id).opacity(isOpen ? 0.28 : 0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.card)
                        .strokeBorder(
                            Tokens.potColor(pot.id).opacity(isOpen ? 0.9 : 0),
                            lineWidth: 2
                        )
                }
                .animation(Tokens.Motion.swap, value: isOpen)
                .animation(Tokens.Motion.swap, value: remaining)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Topf \(pot.id), \(remaining) Teams offen")
            }
        }
    }
}
