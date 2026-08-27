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
                Label("Team hinzufuegen", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Circle()
                    .fill(Tokens.potColor(pot.id))
                    .frame(width: 10, height: 10)
                Text("Topf \(pot.id)")
                Spacer()
                Text("\(pot.teams.count) Teams")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            let issues = viewModel.issues(forPot: pot.id)
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                    ForEach(issues) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.severity == .blocking ? .red : .orange)
                    }
                }
                .font(.caption)
            }
        }
    }
}
