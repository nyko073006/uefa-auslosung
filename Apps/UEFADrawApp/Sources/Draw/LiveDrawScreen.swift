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
            // Das Linienmuster nimmt die Farbe des offenen Topfs auf.
            .background { DrawBackground(accent: Tokens.potColor(viewModel.openPot ?? 1)) }
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
            CompetitionMark(width: 190, tint: .white)
                .padding(.bottom, Tokens.Spacing.medium)

            ZStack {
                Circle()
                    .strokeBorder(Tokens.Brand.cyan.opacity(0.75), lineWidth: 2)
                    .frame(width: 108, height: 108)
                    .shadow(color: Tokens.Brand.cyan.opacity(0.5), radius: 22)

                Circle()
                    .strokeBorder(Tokens.Brand.cyan.opacity(0.2), lineWidth: 1)
                    .frame(width: 132, height: 132)

                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Tokens.Brand.cyan)
                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
            }

            VStack(spacing: Tokens.Spacing.tight) {
                Text("Die Trommel dreht sich")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Die Engine ermittelt eine gültige Auslosung.")
                    .font(.footnote)
                    .foregroundStyle(Tokens.Brand.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Spacing.large)
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: Tokens.Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Tokens.Brand.yellow)

            VStack(spacing: Tokens.Spacing.small) {
                Text("Auslosung fehlgeschlagen")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Tokens.Brand.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Erneut versuchen") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: Tokens.Radius.chip))
        }
        .padding(Tokens.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Text("GEGNER NACH VERBAND")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(Tokens.Brand.textTertiary)
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
                .foregroundStyle(Tokens.Brand.green)
            Text("\(viewModel.completedTeamCount) von \(viewModel.totalTeamCount) Teams ausgelost")
                .contentTransition(.numericText())
        }
        .font(.footnote)
        .foregroundStyle(Tokens.Brand.textSecondary)
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
    .preferredColorScheme(.dark)
}
