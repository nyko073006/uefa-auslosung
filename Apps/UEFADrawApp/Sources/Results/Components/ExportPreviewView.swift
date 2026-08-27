// ExportPreviewView.swift
//
// Reine Darstellung fuer den Bild-Export. Wird ausserhalb der Bildschirmhierarchie
// von `ImageRenderer` gerendert und deshalb bewusst schlicht gehalten.

import SwiftUI

struct ExportPreviewView: View {

    let schedules: [TeamSchedule]
    let seed: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UEFA-Auslosung")
                    .font(.title3.weight(.bold))
                Text("Seed \(seed) - \(schedules.count) Teams")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                alignment: .leading,
                spacing: Tokens.Spacing.medium
            ) {
                ForEach(schedules) { schedule in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(schedule.team.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Tokens.potColor(schedule.team.potIndex))

                        ForEach(schedule.opponents) { opponent in
                            Text("\(opponent.venue.shortLabel)  \(opponent.team.name)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 900)
        .background(Color.white)
    }
}
