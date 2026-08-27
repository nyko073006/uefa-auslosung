// SetupViewModel.swift
//
// Haelt die Konfiguration der Auslosung.
//
// Regelwissen liegt hier bewusst nicht: die Constraint-Liste kommt aus der Engine,
// die fachliche Pruefung ebenso. Die App prueft nur Darstellungsfragen.

import Foundation
import Observation

@MainActor
@Observable
final class SetupViewModel {

    // MARK: - Abhaengigkeiten

    private let port: any DrawEnginePort
    private let router: AppRouter

    // MARK: - Zustand

    var pots: [Pot]
    var enabledConstraintIDs: Set<String>
    var seedText: String

    private(set) var constraints: [ConstraintDescriptor]
    private(set) var issues: [SetupIssue] = []

    init(port: any DrawEnginePort, router: AppRouter) {
        let descriptors = port.availableConstraints()
        self.port = port
        self.router = router
        self.constraints = descriptors
        self.pots = SampleTeams.defaultPots()
        self.enabledConstraintIDs = Set(descriptors.map(\.id))
        self.seedText = String(UInt64.random(in: 1...999_999))
    }

    // MARK: - Abgeleitete Werte

    var availableAssociations: [Association] {
        let used = Set(pots.flatMap(\.teams).map(\.association))
        return Array(used).sorted { $0.id < $1.id }
    }

    var seed: UInt64 {
        UInt64(seedText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    var isSeedValid: Bool {
        let trimmed = seedText.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && UInt64(trimmed) != nil
    }

    var blockingIssues: [SetupIssue] {
        issues.filter { $0.severity == .blocking }
    }

    var warningIssues: [SetupIssue] {
        issues.filter { $0.severity == .warning }
    }

    var isStartable: Bool {
        isSeedValid && blockingIssues.isEmpty
    }

    var totalTeamCount: Int {
        pots.reduce(0) { $0 + $1.teams.count }
    }

    func issues(forPot potID: Int) -> [SetupIssue] {
        issues.filter { $0.potIndex == potID }
    }

    // MARK: - Aktionen

    /// Fachliche Pruefung delegieren. Was gueltig ist, weiss die Engine.
    func validate() {
        issues = port.validate(currentSetup())
    }

    func randomizeSeed() {
        seedText = String(UInt64.random(in: 1...999_999))
        validate()
    }

    func addTeam(toPot potID: Int) {
        guard let index = pots.firstIndex(where: { $0.id == potID }) else { return }
        let fallback = availableAssociations.first ?? SampleTeams.associations[0]
        pots[index].teams.append(
            Team(name: "", association: fallback, potIndex: potID)
        )
        validate()
    }

    func removeTeams(atOffsets offsets: IndexSet, fromPot potID: Int) {
        guard let index = pots.firstIndex(where: { $0.id == potID }) else { return }
        pots[index].teams.remove(atOffsets: offsets)
        validate()
    }

    func moveTeam(_ team: Team, toPot targetPotID: Int) {
        guard team.potIndex != targetPotID,
              let sourceIndex = pots.firstIndex(where: { $0.id == team.potIndex }),
              let targetIndex = pots.firstIndex(where: { $0.id == targetPotID }),
              let teamIndex = pots[sourceIndex].teams.firstIndex(where: { $0.id == team.id })
        else { return }

        var moved = pots[sourceIndex].teams.remove(at: teamIndex)
        moved.potIndex = targetPotID
        pots[targetIndex].teams.append(moved)
        validate()
    }

    func toggleConstraint(_ id: String, isOn: Bool) {
        if isOn {
            enabledConstraintIDs.insert(id)
        } else {
            enabledConstraintIDs.remove(id)
        }
        validate()
    }

    func resetToDefaults() {
        pots = SampleTeams.defaultPots()
        enabledConstraintIDs = Set(constraints.map(\.id))
        validate()
    }

    func start() {
        validate()
        guard isStartable else { return }
        router.push(.liveDraw(setup: currentSetup(), seed: seed))
    }

    // MARK: - Intern

    func currentSetup() -> DrawSetup {
        DrawSetup(pots: pots, enabledConstraintIDs: enabledConstraintIDs)
    }
}
