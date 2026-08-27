// TeamScheduleCard.swift
//
// Swiss Model heisst: keine Gruppentabelle, sondern ein Spielplan je Team.

import SwiftUI

struct TeamScheduleCard: View {

    let schedule: TeamSchedule

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 0) {
                ForEach(Array(schedule.opponentsByPot.enumerated()), id: \.element.pot) { _, group in
                    VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                        Text("Aus Topf \(group.pot)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Tokens.potColor(group.pot))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Tokens.Spacing.small)

                        ForEach(group.opponents) { opponent in
                            OpponentRow(opponent: opponent)
                        }
                    }
                }
            }
        } label: {
            header
        }
        .animation(
            Tokens.Motion.respecting(reduceMotion, Tokens.Motion.move),
            value: isExpanded
        )
    }

    private var header: some View {
        HStack(spacing: Tokens.Spacing.medium) {
            TeamLogoView(team: schedule.team, size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.team.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: Tokens.Spacing.tight) {
                    Text("Topf \(schedule.team.potIndex)")
                    Text("·")
                    Text(schedule.team.association.name)
                }
                .font(.caption2)
                .foregroundStyle(Tokens.Brand.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                venuePill(count: schedule.homeCount, venue: .home)
                venuePill(count: schedule.awayCount, venue: .away)
            }
        }
        .padding(.vertical, 2)
    }

    private func venuePill(count: Int, venue: Venue) -> some View {
        HStack(spacing: 2) {
            Image(systemName: venue.symbolName)
                .font(.system(size: 9))
            Text("\(count)")
                .font(.caption2.monospacedDigit().weight(.medium))
        }
        .foregroundStyle(Tokens.Brand.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Tokens.Brand.surface))
        .accessibilityLabel("\(count) \(venue == .home ? "Heimspiele" : "Auswärtsspiele")")
    }
}
