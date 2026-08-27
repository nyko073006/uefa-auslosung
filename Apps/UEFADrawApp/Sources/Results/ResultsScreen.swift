// ResultsScreen.swift
//
// Das fertige Ergebnis: 36 Spielplaene, durchsuchbar und teilbar.

import SwiftUI

struct ResultsScreen: View {

    @Bindable private var viewModel: ResultsViewModel

    init(viewModel: ResultsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Section {
                potFilterRow
            }

            Section {
                if viewModel.schedules.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    ForEach(viewModel.schedules) { schedule in
                        TeamScheduleCard(schedule: schedule)
                    }
                }
            } header: {
                Text("\(viewModel.schedules.count) von \(viewModel.teamCount) Teams")
            }

            Section("Lauf") {
                LabeledContent("Seed") {
                    Text(viewModel.seedText)
                        .font(.body.monospacedDigit())
                        .textSelection(.enabled)
                }
                LabeledContent("Paarungen", value: "\(viewModel.matchupCount)")
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Team oder Verband suchen")
        .navigationTitle("Ergebnis")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden()
        .task { viewModel.prepareImageExport() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(
                        item: viewModel.export,
                        preview: SharePreview(viewModel.export.summaryLine)
                    ) {
                        Label("Als Text teilen", systemImage: "doc.plaintext")
                    }

                    if let imageExport = viewModel.imageExport {
                        ShareLink(
                            item: imageExport,
                            preview: SharePreview(imageExport.summaryLine)
                        ) {
                            Label("Als Bild teilen", systemImage: "photo")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Ergebnis teilen")
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Neue Auslosung") {
                    viewModel.startNewDraw()
                }
            }
        }
    }

    private var potFilterRow: some View {
        Picker("Topf", selection: $viewModel.potFilter) {
            Text("Alle").tag(Int?.none)
            ForEach(viewModel.availablePots, id: \.self) { pot in
                Text("Topf \(pot)").tag(Int?.some(pot))
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    ResultsPreviewHost()
}

private struct ResultsPreviewHost: View {
    @State private var run: DrawRun?

    var body: some View {
        NavigationStack {
            if let run {
                ResultsScreen(
                    viewModel: ResultsViewModel(run: run, router: AppRouter())
                )
            } else {
                ProgressView()
                    .task { run = await SampleTeams.previewRun() }
            }
        }
    }
}
