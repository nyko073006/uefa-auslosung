// RootView.swift
//
// Zentraler NavigationStack. Die Navigationsziele bauen hier ihr ViewModel aus
// Route-Nutzlast und Abhaengigkeiten - die Screens selbst verdrahten nur noch.

import SwiftUI

struct RootView: View {

    let model: AppModel

    var body: some View {
        NavigationStack(path: Bindable(model.router).path) {
            SetupScreen(viewModel: model.setupViewModel)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .liveDraw(let setup, let seed):
            LiveDrawScreen(
                viewModel: model.makeLiveDrawViewModel(setup: setup, seed: seed)
            )
        case .results(let run):
            ResultsScreen(
                viewModel: model.makeResultsViewModel(run: run)
            )
        }
    }
}

#Preview {
    RootView(model: AppModel(engine: MockDrawEngine()))
}
