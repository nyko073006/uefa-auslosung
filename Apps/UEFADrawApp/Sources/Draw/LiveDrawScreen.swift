// LiveDrawScreen.swift
//
// Die laufende Auslosung. Der Body liest ausschliesslich aufbereitete Werte
// aus dem ViewModel - keine Ableitung, keine Bewertung, keine Regel.

import SwiftUI

struct LiveDrawScreen: View {

    @State private var viewModel: LiveDrawViewModel

    init(viewModel: LiveDrawViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Auslosung laeuft")
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
            Image(systemName: "circle.hexagongrid.circle")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            VStack(spacing: Tokens.Spacing.tight) {
                Text("Die Trommel dreht sich")
                    .font(.headline)
                Text("Die Engine ermittelt eine gueltige Auslosung.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                if let rejection = viewModel.activeRejection {
                    RejectionBanner(candidate: rejection.team, reason: rejection.reason)
                }

                AssociationTallyBar(tally: viewModel.associationTally)

                OpponentSlotGrid(
                    pots: viewModel.potIDs,
                    slotsPerPot: viewModel.opponentsPerPot,
                    revealed: viewModel.revealedOpponents
                )

                Text("\(viewModel.completedTeamCount) von \(viewModel.totalTeamCount) Teams ausgelost")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Tokens.Spacing.medium)
            .animation(Tokens.Motion.banner, value: viewModel.activeRejection?.reason)
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
