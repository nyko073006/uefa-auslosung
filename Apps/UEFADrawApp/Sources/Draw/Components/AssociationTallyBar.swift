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

    var body: some View {
        if !tally.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Spacing.small) {
                    ForEach(tally, id: \.association) { entry in
                        HStack(spacing: Tokens.Spacing.tight) {
                            Text(entry.association.id)
                                .font(.caption2.weight(.semibold))
                            Text("\(entry.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Tokens.Spacing.small)
                        .padding(.vertical, Tokens.Spacing.tight)
                        .background {
                            Capsule().fill(.secondary.opacity(0.12))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.association.name): \(entry.count) Gegner")
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}
