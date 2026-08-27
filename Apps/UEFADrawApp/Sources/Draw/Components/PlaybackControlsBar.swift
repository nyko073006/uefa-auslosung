// PlaybackControlsBar.swift

import SwiftUI

struct PlaybackControlsBar: View {

    let isPaused: Bool
    let speed: PlaybackController.Speed
    let progress: Double
    let canStepForward: Bool
    let onTogglePause: () -> Void
    let onSpeedChange: @MainActor @Sendable (PlaybackController.Speed) -> Void
    let onStepForward: () -> Void
    let onReplay: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.small) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)

            HStack(spacing: Tokens.Spacing.medium) {
                Button(action: onTogglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .frame(width: 28)
                }
                .accessibilityLabel(isPaused ? "Fortsetzen" : "Pausieren")

                Button(action: onStepForward) {
                    Image(systemName: "forward.frame.fill")
                }
                .disabled(!canStepForward)
                .accessibilityLabel("Einen Schritt weiter")

                Picker("Tempo", selection: Binding(get: { speed }, set: onSpeedChange)) {
                    ForEach(PlaybackController.Speed.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button(action: onReplay) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Auslosung wiederholen")

                Button(action: onSkip) {
                    Image(systemName: "forward.end.fill")
                }
                .accessibilityLabel("Zum Ergebnis springen")
            }
            .buttonStyle(.bordered)
            .font(.body)
        }
        .padding(Tokens.Spacing.medium)
        .background(.bar)
    }
}
