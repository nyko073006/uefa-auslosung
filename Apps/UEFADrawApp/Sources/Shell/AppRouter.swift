// AppRouter.swift
//
// Typsichere Navigation ueber einen zentralen NavigationStack-Pfad.
//
// Der Router wird in die ViewModels injiziert, nicht in die Views. Dadurch bleibt
// der View-Body frei von Entscheidungen und die Navigation testbar (Spy-Router).

import Foundation
import Observation

enum Route: Hashable {
    case liveDraw(setup: DrawSetup, seed: UInt64)
    case results(DrawRun)
}

@MainActor
@Observable
final class AppRouter {
    var path: [Route] = []

    init(path: [Route] = []) {
        self.path = path
    }

    func push(_ route: Route) {
        path.append(route)
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Ersetzt den obersten Eintrag - genutzt beim Uebergang Live-Draw -> Ergebnis,
    /// damit "Zurueck" nicht in eine bereits gelaufene Auslosung fuehrt.
    func replaceTop(with route: Route) {
        if path.isEmpty {
            path = [route]
        } else {
            path[path.count - 1] = route
        }
    }
}
