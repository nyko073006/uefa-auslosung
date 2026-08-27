// TeamRowView.swift

import SwiftUI

struct TeamRowView: View {

    @Binding var team: Team
    let associations: [Association]
    let otherPots: [Int]
    let onMove: (Int) -> Void

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            TeamLogoView(team: team, size: 26)

            TextField("Teamname", text: $team.name)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif

            Picker("Verband", selection: $team.association) {
                ForEach(associations) { association in
                    Text(association.id).tag(association)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            if !otherPots.isEmpty {
                Menu {
                    ForEach(otherPots, id: \.self) { pot in
                        Button("Nach Topf \(pot)") { onMove(pot) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .foregroundStyle(Tokens.Brand.textSecondary)
                }
                .accessibilityLabel("Team in anderen Topf verschieben")
            }
        }
    }
}
