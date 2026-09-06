// ExportPreviewView.swift
//
// Reine Darstellung fuer den Bild-Export. Wird ausserhalb der Bildschirmhierarchie
// von `ImageRenderer` gerendert und deshalb bewusst schlicht gehalten.
//
// Feste Farben statt Systemfarben: der Renderer kennt kein Farbschema, ein
// `.primary` waere hier schwarz auf dunklem Grund.

import SwiftUI

struct ExportPreviewView: View {

    let schedules: [TeamSchedule]
    let seed: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
            header

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3),
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(schedules) { schedule in
                    scheduleBlock(schedule)
                }
            }
        }
        .padding(28)
        .frame(width: 1100)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Tokens.Brand.mid, Tokens.Brand.deep],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Tokens.Brand.lift.opacity(0.7), .clear],
                    center: UnitPoint(x: 0.5, y: 0),
                    startRadius: 0,
                    endRadius: 620
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("UEFA-AUSLOSUNG")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.white)
                Text("Ligaphase – \(schedules.count) Teams")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.Brand.textSecondary)
            }

            Spacer()

            Text("SEED \(seed)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .tracking(1)
                .foregroundStyle(Tokens.Brand.cyan)
        }
    }

    private func scheduleBlock(_ schedule: TeamSchedule) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Capsule()
                    .fill(Tokens.potColor(schedule.team.potIndex))
                    .frame(width: 10, height: 3)
                Text(schedule.team.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            ForEach(schedule.opponents) { opponent in
                HStack(spacing: 5) {
                    Text(opponent.venue.shortLabel)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Tokens.potColor(opponent.fromPot))
                        .frame(width: 9, alignment: .leading)
                    Text(opponent.team.name)
                        .font(.system(size: 9))
                        .foregroundStyle(Tokens.Brand.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Tokens.Brand.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Tokens.Brand.hairline, lineWidth: 0.5)
        }
    }
}
