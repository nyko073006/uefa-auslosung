// AssociationTallyBar.swift
//
// Verteilung der bisherigen Gegner nach Verband.
//
// Bewusst nur eine Auszaehlung des bereits Aufgedeckten: kein "voll", kein
// "gesperrt", kein Vergleich gegen ein Limit. Ob eine Anzahl noch zulaessig ist,
// entscheidet allein die Engine und teilt es ueber ihre Begruendungen mit.

import SwiftUI

struct AssociationTallyBar: View {

    let tally: [(association: Association, count: Int)]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Spacing.small) {
                ForEach(tally, id: \.association) { entry in
                    chip(for: entry)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.move), value: tally.count)
    }

    private func chip(for entry: (association: Association, count: Int)) -> some View {
        HStack(spacing: Tokens.Spacing.tight) {
            Text(entry.association.id)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)

            Text("\(entry.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Tokens.Brand.textSecondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Tokens.Spacing.small)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(Tokens.Brand.surface)
        }
        .overlay {
            Capsule().strokeBorder(Tokens.Brand.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.association.name): \(entry.count) Gegner")
    }
}
