// PotSectionView.swift

import SwiftUI

struct PotSectionView: View {

    @Bindable var viewModel: SetupViewModel
    let potArrayIndex: Int

    private var pot: Pot {
        viewModel.pots[potArrayIndex]
    }

    private var otherPots: [Int] {
        viewModel.pots.map(\.id).filter { $0 != pot.id }
    }

    var body: some View {
        Section {
            ForEach($viewModel.pots[potArrayIndex].teams) { $team in
                TeamRowView(
                    team: $team,
                    associations: viewModel.availableAssociations,
                    otherPots: otherPots
                ) { target in
                    viewModel.moveTeam(team, toPot: target)
                }
            }
            .onDelete { offsets in
                viewModel.removeTeams(atOffsets: offsets, fromPot: pot.id)
            }

            Button {
                viewModel.addTeam(toPot: pot.id)
            } label: {
                Label("Team hinzufügen", systemImage: "plus.circle.fill")
                    .foregroundStyle(Tokens.potColor(pot.id))
            }
        } header: {
            HStack(spacing: Tokens.Spacing.small) {
                Capsule()
                    .fill(Tokens.potGradient(pot.id))
                    .frame(width: 16, height: 5)

                Text("Topf \(pot.id)")

                Spacer()

                Text("\(pot.teams.count)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
            }
        } footer: {
            let issues = viewModel.issues(forPot: pot.id)
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                    ForEach(issues) { issue in
                        IssueRow(issue: issue)
                    }
                }
                .font(.caption)
            }
        }
    }
}
