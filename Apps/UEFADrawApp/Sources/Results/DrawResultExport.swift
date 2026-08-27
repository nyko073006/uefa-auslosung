// DrawResultExport.swift
//
// Teilbare Darstellung des Ergebnisses. Die Formatierung liegt hier und nicht
// im View - der View reicht das Objekt nur an `ShareLink` weiter.

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct DrawResultExport: Transferable, Sendable {

    let schedules: [TeamSchedule]
    let seed: UInt64

    // MARK: - Text

    var plainText: String {
        var lines: [String] = []
        lines.append("UEFA-Auslosung - Ergebnis")
        lines.append("Seed: \(seed)")
        lines.append("Teams: \(schedules.count)")
        lines.append("")

        for schedule in schedules.sorted(by: sortByPotThenName) {
            lines.append("\(schedule.team.name) (Topf \(schedule.team.potIndex), \(schedule.team.association.id))")

            for group in schedule.opponentsByPot {
                let entries = group.opponents.map { opponent in
                    "\(opponent.team.name) [\(opponent.venue.shortLabel)]"
                }
                lines.append("  Topf \(group.pot): \(entries.joined(separator: ", "))")
            }

            lines.append("  \(schedule.homeCount) Heim / \(schedule.awayCount) Auswärts")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    var summaryLine: String {
        "UEFA-Auslosung, \(schedules.count) Teams, Seed \(seed)"
    }

    private func sortByPotThenName(_ lhs: TeamSchedule, _ rhs: TeamSchedule) -> Bool {
        lhs.team.potIndex == rhs.team.potIndex
            ? lhs.team.name < rhs.team.name
            : lhs.team.potIndex < rhs.team.potIndex
    }

    // MARK: - Transferable

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { export in
            Data(export.plainText.utf8)
        }
        .suggestedFileName { "uefa-auslosung-\($0.seed).txt" }

        ProxyRepresentation { export in
            export.plainText
        }
    }
}

/// Bild-Variante des Ergebnisses. Die Pixel entstehen im ViewModel via
/// `ImageRenderer`; hier wird nur die fertige PNG-Datei teilbar gemacht.
struct DrawResultImageExport: Transferable, Sendable {

    let pngData: Data
    let seed: UInt64

    var summaryLine: String {
        "UEFA-Auslosung als Bild, Seed \(seed)"
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { export in
            export.pngData
        }
        .suggestedFileName { "uefa-auslosung-\($0.seed).png" }
    }
}
