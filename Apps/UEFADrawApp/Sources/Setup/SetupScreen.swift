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
                sectionTitle("Zufall")
            } footer: {
                footnote("Derselbe Seed erzeugt dieselbe Auslosung – teilbar und wiederholbar.")
            }
            .listRowBackground(Tokens.Brand.surface)

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
                    sectionTitle("Regeln")
                } footer: {
                    footnote("Die Regeln stammen aus der Draw-Engine. Die App bewertet sie nicht.")
                }
                .listRowBackground(Tokens.Brand.surface)
            }

            ForEach(viewModel.pots.indices, id: \.self) { index in
                PotSectionView(viewModel: viewModel, potArrayIndex: index)
            }

            let globalIssues = viewModel.issues.filter { $0.potIndex == nil }
            if !globalIssues.isEmpty {
                Section {
                    ForEach(globalIssues) { issue in
                        IssueRow(issue: issue)
                    }
                } header: {
                    sectionTitle("Hinweise")
                }
                .listRowBackground(Tokens.Brand.surface)
            }
        }
        .brandScreenBackground()
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Tokens.Brand.textSecondary)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Tokens.Brand.textSecondary)
    }

    private var startBar: some View {
        VStack(spacing: Tokens.Spacing.small) {
            HStack(spacing: Tokens.Spacing.small) {
                Label("\(viewModel.totalTeamCount) Teams", systemImage: "person.3.fill")
                    .contentTransition(.numericText())
                    .foregroundStyle(Tokens.Brand.textSecondary)

                Spacer()

                if let first = viewModel.blockingIssues.first {
                    Label(first.message, systemImage: "exclamationmark.circle.fill")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(Tokens.Brand.magenta)
                } else {
                    Label("Bereit", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Tokens.Brand.green)
                }
            }
            .font(.footnote)

            Button {
                viewModel.start()
            } label: {
                Label("Auslosung starten", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Tokens.Brand.deep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                            .fill(
                                viewModel.isStartable
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Tokens.Brand.cyan, Tokens.Brand.green],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                    : AnyShapeStyle(Tokens.Brand.hairline)
                            )
                    }
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!viewModel.isStartable)
        }
        .padding(Tokens.Spacing.medium)
        .frame(maxWidth: Tokens.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Brand.hairline).frame(height: 1)
        }
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
        .foregroundStyle(issue.severity == .blocking ? Tokens.Brand.magenta : Tokens.Brand.yellow)
    }
}

#Preview {
    let model = AppModel(engine: MockDrawEngine())
    return NavigationStack {
        SetupScreen(viewModel: model.setupViewModel)
    }
    .preferredColorScheme(.dark)
}
