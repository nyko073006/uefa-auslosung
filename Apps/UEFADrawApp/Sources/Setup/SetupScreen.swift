// SetupScreen.swift
//
// Konfiguration der Auslosung. Der Body enthaelt keine Entscheidung - er bindet
// an das ViewModel und reicht Aktionen weiter.

import SwiftUI

struct SetupScreen: View {

    @Bindable private var viewModel: SetupViewModel

    init(viewModel: SetupViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            Section("Zufall") {
                SeedFieldView(
                    seedText: $viewModel.seedText,
                    isValid: viewModel.isSeedValid,
                    onRandomize: viewModel.randomizeSeed
                )
            }

            if !viewModel.constraints.isEmpty {
                Section {
                    ForEach(viewModel.constraints) { descriptor in
                        ConstraintToggleRow(
                            descriptor: descriptor,
                            isOn: viewModel.enabledConstraintIDs.contains(descriptor.id)
                        ) { isOn in
                            viewModel.toggleConstraint(descriptor.id, isOn: isOn)
                        }
                    }
                } header: {
                    Text("Regeln")
                } footer: {
                    Text("Die Regeln stammen aus der Draw-Engine. Die App bewertet sie nicht.")
                }
            }

            ForEach(viewModel.pots.indices, id: \.self) { index in
                PotSectionView(viewModel: viewModel, potArrayIndex: index)
            }

            if !viewModel.blockingIssues.isEmpty || !viewModel.warningIssues.isEmpty {
                Section("Hinweise") {
                    ForEach(viewModel.issues.filter { $0.potIndex == nil }) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(issue.severity == .blocking ? .red : .orange)
                    }
                }
            }
        }
        .navigationTitle("Auslosung einrichten")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Auf Standard zuruecksetzen", systemImage: "arrow.counterclockwise") {
                        viewModel.resetToDefaults()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            startBar
        }
        .onAppear { viewModel.validate() }
        .onChange(of: viewModel.pots) { _, _ in viewModel.validate() }
        .onChange(of: viewModel.seedText) { _, _ in viewModel.validate() }
    }

    private var startBar: some View {
        VStack(spacing: Tokens.Spacing.small) {
            HStack {
                Label("\(viewModel.totalTeamCount) Teams", systemImage: "person.3.fill")
                Spacer()
                if let first = viewModel.blockingIssues.first {
                    Text(first.message)
                        .lineLimit(1)
                        .foregroundStyle(.red)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Button {
                viewModel.start()
            } label: {
                Label("Auslosung starten", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.isStartable)
        }
        .padding(Tokens.Spacing.medium)
        .background(.bar)
    }
}

#Preview {
    let model = AppModel(engine: MockDrawEngine())
    return NavigationStack {
        SetupScreen(viewModel: model.setupViewModel)
    }
}
