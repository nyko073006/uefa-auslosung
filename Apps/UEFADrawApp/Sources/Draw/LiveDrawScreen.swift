// LiveDrawScreen.swift
//
// Die laufende Auslosung. Der Body liest ausschliesslich aufbereitete Werte
// aus dem ViewModel - keine Ableitung, keine Bewertung, keine Regel.

import SwiftUI

struct LiveDrawScreen: View {

    @State private var viewModel: LiveDrawViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: LiveDrawViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Auslosung läuft")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task { await viewModel.load() }
            .onDisappear { viewModel.teardown() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .preparing:
            preparingView
        case .failed(let message):
            failureView(message)
        case .revealing, .finished:
            revealView
        }
    }

    // MARK: - Zustaende

    private var preparingView: some View {
        VStack(spacing: Tokens.Spacing.large) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.potColor(1), Tokens.potColor(4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Tokens.potColor(1).opacity(0.3), radius: 16, y: 8)

                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
            }

            VStack(spacing: Tokens.Spacing.tight) {
                Text("Die Trommel dreht sich")
                    .font(.title3.weight(.semibold))
                Text("Die Engine ermittelt eine gültige Auslosung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Spacing.large)
    }

    private func failureView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Auslosung fehlgeschlagen", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Erneut versuchen") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var revealView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
                PotStackView(
                    pots: viewModel.pots,
                    remainingByPot: viewModel.remainingByPot,
                    openPot: viewModel.openPot
                )

                DrawnTeamCard(
                    team: viewModel.currentTeam,
                    revealedCount: viewModel.revealedOpponents.count,
                    expectedCount: viewModel.opponentsPerTeam
                )

                // Reservierte Hoehe waere hier falsch: der Hinweis erscheint nur
                // gelegentlich und soll den Rest nicht dauerhaft nach unten druecken.
                if let rejection = viewModel.activeRejection {
                    RejectionBanner(candidate: rejection.team, reason: rejection.reason)
                        .revealTransition(reduceMotion: reduceMotion)
                }

                if !viewModel.associationTally.isEmpty {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                        Text("Gegner nach Verband")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        AssociationTallyBar(tally: viewModel.associationTally)
                    }
                }

                OpponentSlotGrid(
                    pots: viewModel.potIDs,
                    slotsPerPot: viewModel.opponentsPerPot,
                    revealed: viewModel.revealedOpponents
                )

                footer
            }
            .padding(Tokens.Spacing.medium)
            // Lesbare Spaltenbreite: ohne Deckelung zerfaellt der Inhalt auf dem
            // iPad in weite Leerflaechen.
            .frame(maxWidth: Tokens.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .animation(
                Tokens.Motion.respecting(reduceMotion, Tokens.Motion.enter),
                value: viewModel.activeRejection?.reason
            )
        }
        .safeAreaInset(edge: .bottom) {
            if let playback = viewModel.playback {
                PlaybackControlsBar(
                    isPaused: playback.isPaused,
                    speed: playback.speed,
                    progress: playback.progress,
                    canStepForward: playback.canStepForward,
                    onTogglePause: playback.togglePause,
                    onSpeedChange: { @MainActor speed in playback.setSpeed(speed) },
                    onStepForward: playback.stepForward,
                    onReplay: playback.replay,
                    onSkip: viewModel.skipToResult
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Tokens.Spacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("\(viewModel.completedTeamCount) von \(viewModel.totalTeamCount) Teams ausgelost")
                .contentTransition(.numericText())
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Tokens.Spacing.small)
        .animation(
            Tokens.Motion.respecting(reduceMotion, Tokens.Motion.state),
            value: viewModel.completedTeamCount
        )
    }
}

#Preview {
    let model = AppModel(engine: MockDrawEngine())
    let setup = SampleTeams.defaultSetup(
        enabledConstraintIDs: Set(MockDrawEngine().availableConstraints().map(\.id))
    )
    return NavigationStack {
        LiveDrawScreen(viewModel: model.makeLiveDrawViewModel(setup: setup, seed: 2026))
    }
}
