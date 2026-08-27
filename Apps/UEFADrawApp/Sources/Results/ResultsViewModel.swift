// ResultsViewModel.swift
//
// Aufbereitung des fertigen Laufs fuer die Ergebnisansicht.
// Swiss Model heisst: keine Gruppentabelle, sondern 36 Spielplaene.

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ResultsViewModel {

    private let router: AppRouter

    let run: DrawRun
    private let allSchedules: [TeamSchedule]

    var searchText: String = ""
    var potFilter: Int?

    init(run: DrawRun, router: AppRouter) {
        self.run = run
        self.router = router
        self.allSchedules = run.schedules()
    }

    // MARK: - Anzeigewerte

    var schedules: [TeamSchedule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allSchedules.filter { schedule in
            let matchesPot = potFilter.map { $0 == schedule.team.potIndex } ?? true
            guard matchesPot else { return false }
            guard !query.isEmpty else { return true }

            if schedule.team.name.lowercased().contains(query) { return true }
            if schedule.team.association.name.lowercased().contains(query) { return true }
            return schedule.opponents.contains { $0.team.name.lowercased().contains(query) }
        }
    }

    var availablePots: [Int] {
        run.setup.pots.map(\.id).sorted()
    }

    var seedText: String {
        String(run.seed)
    }

    var teamCount: Int {
        allSchedules.count
    }

    var matchupCount: Int {
        run.matchups.count
    }

    var isFiltered: Bool {
        potFilter != nil || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Export

    var export: DrawResultExport {
        DrawResultExport(schedules: allSchedules, seed: run.seed)
    }

    private(set) var imageExport: DrawResultImageExport?

    /// Rendert das Ergebnis einmalig als PNG. Die Bilderzeugung gehoert hierher
    /// und nicht in den View - dort wird nur das fertige Objekt geteilt.
    func prepareImageExport() {
        guard imageExport == nil else { return }

        let renderer = ImageRenderer(
            content: ExportPreviewView(schedules: allSchedules, seed: run.seed)
        )
        renderer.scale = 2

        guard let data = Self.pngData(from: renderer) else { return }
        imageExport = DrawResultImageExport(pngData: data, seed: run.seed)
    }

    private static func pngData(from renderer: ImageRenderer<ExportPreviewView>) -> Data? {
        #if canImport(UIKit)
        return renderer.uiImage?.pngData()
        #elseif canImport(AppKit)
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }

    // MARK: - Aktionen

    func clearFilters() {
        searchText = ""
        potFilter = nil
    }

    func startNewDraw() {
        router.popToRoot()
    }
}
