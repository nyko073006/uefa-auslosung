// TeamScheduleCard.swift
//
// Swiss Model heisst: keine Gruppentabelle, sondern ein Spielplan je Team.

import SwiftUI

struct TeamScheduleCard: View {

    let schedule: TeamSchedule

    var body: some View {
        DisclosureGroup {
            VStack(spacing: Tokens.Spacing.tight) {
                ForEach(schedule.opponents) { opponent in
                    OpponentRow(opponent: opponent)
                }
            }
            .padding(.top, Tokens.Spacing.tight)
        } label: {
            header
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Spacing.small) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Tokens.potColor(schedule.team.potIndex))
                .frame(width: 4, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(schedule.team.name)
                    .font(.subheadline.weight(.semibold))
                Text("Topf \(schedule.team.potIndex) - \(schedule.team.association.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("\(schedule.homeCount)H / \(schedule.awayCount)A")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
