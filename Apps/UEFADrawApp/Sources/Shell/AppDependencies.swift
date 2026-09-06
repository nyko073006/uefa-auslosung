// AppDependencies.swift
//
// Zusammensetzung der App: Engine, Router und das langlebige Setup-ViewModel.
//
// Der Austausch der Engine ist eine Ein-Zeilen-Aenderung an der Stelle, an der
// `AppModel` gebaut wird. Views und ViewModels arbeiten nur gegen `DrawEnginePort`.

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {

    let engine: any DrawEnginePort
    let router: AppRouter
    let setupViewModel: SetupViewModel

    init(engine: any DrawEnginePort) {
        let router = AppRouter()
        self.engine = engine
        self.router = router
        self.setupViewModel = SetupViewModel(port: engine, router: router)
    }

    // MARK: - Fabriken fuer die Navigationsziele

    func makeLiveDrawViewModel(setup: DrawSetup, seed: UInt64) -> LiveDrawViewModel {
        LiveDrawViewModel(setup: setup, seed: seed, port: engine, router: router)
    }

    func makeResultsViewModel(run: DrawRun) -> ResultsViewModel {
        ResultsViewModel(run: run, router: router)
    }
}
