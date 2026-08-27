// UEFADrawApp.swift
//
// Einstiegspunkt der App.
//
// Hier - und nur hier - wird entschieden, welche Engine-Implementierung laeuft.
// BEIM MERGE mit feature/draw-engine: `MockDrawEngine()` durch den Adapter auf
// die echte DrawEngine ersetzen. Sonst aendert sich nichts.

import SwiftUI

@main
@MainActor
struct UEFADrawApp: App {

    @State private var model = AppModel(engine: MockDrawEngine())

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
