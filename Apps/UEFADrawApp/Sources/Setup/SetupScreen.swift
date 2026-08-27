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
            Section {
                SeedFieldView(
                    seedText: $viewModel.seedText,
                    isValid: viewModel.isSeedValid,
                    onRandomize: viewModel.randomizeSeed
                )
            } header: {
                Text("Zufall")
            } footer: {
                Text("Derselbe Seed erzeugt dieselbe Auslosung – teilbar und wiederholbar.")
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

            let globalIssues = viewModel.issues.filter { $0.potIndex == nil }
            if !globalIssues.isEmpty {
                Section("Hinweise") {
                    ForEach(globalIssues) { issue in
                        IssueRow(issue: issue)
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
                    Button("Auf Standard zurücksetzen", systemImage: "arrow.counterclockwise") {
                        viewModel.resetToDefaults()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { startBar }
        .onAppear { viewModel.validate() }
        .onChange(of: viewModel.pots) { _, _ in viewModel.validate() }
        .onChange(of: viewModel.seedText) { _, _ in viewModel.validate() }
    }

    private var startBar: some View {
        VStack(spacing: Tokens.Spacing.small) {
            HStack(spacing: Tokens.Spacing.small) {
                Label("\(viewModel.totalTeamCount) Teams", systemImage: "person.3.fill")
                    .contentTransition(.numericText())

                Spacer()

                if let first = viewModel.blockingIssues.first {
                    Label(first.message, systemImage: "exclamationmark.circle.fill")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.red)
                } else {
                    Label("Bereit", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Button {
                viewModel.start()
            } label: {
                Label("Auslosung starten", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Tokens.Radius.chip))
            .controlSize(.large)
            .disabled(!viewModel.isStartable)
        }
        .padding(Tokens.Spacing.medium)
        .background(.bar)
        .animation(Tokens.Motion.state, value: viewModel.isStartable)
    }
}

/// Einheitliche Darstellung eines Befunds aus der Engine-Validierung.
struct IssueRow: View {

    let issue: SetupIssue

    var body: some View {
        Label {
            Text(issue.message)
        } icon: {
            Image(systemName: issue.severity == .blocking
                  ? "exclamationmark.octagon.fill"
                  : "exclamationmark.triangle.fill")
        }
        .foregroundStyle(issue.severity == .blocking ? .red : .orange)
    }
}

#Preview {
    let model = AppModel(engine: MockDrawEngine())
    return NavigationStack {
        SetupScreen(viewModel: model.setupViewModel)
    }
}
