// PlaybackControlsBar.swift
//
// Kompakt gehalten: ein segmentiertes Tempo-Picker sprengt auf dem iPhone die
// Breite und schiebt ueber den safeAreaInset den ganzen Inhalt aus dem Bild.
// Deshalb liegt das Tempo in einem Menue.

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Tokens.Spacing.medium) {
            progressTrack

            HStack(spacing: Tokens.Spacing.small) {
                primaryButton

                iconButton("forward.frame.fill", label: "Einen Schritt weiter", action: onStepForward)
                    .disabled(!canStepForward)

                speedMenu

                Spacer(minLength: 0)

                iconButton("arrow.counterclockwise", label: "Wiederholen", action: onReplay)
                iconButton("forward.end.fill", label: "Zum Ergebnis springen", action: onSkip)
            }
        }
        .padding(.horizontal, Tokens.Spacing.medium)
        .padding(.vertical, Tokens.Spacing.medium)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Brand.hairline).frame(height: 1)
        }
    }

    private var progressTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.Brand.hairline)
                Capsule()
                    .fill(Tokens.Brand.cyan)
                    .frame(width: max(0, proxy.size.width * progress))
            }
        }
        .frame(height: 4)
        .animation(Tokens.Motion.respecting(reduceMotion, Tokens.Motion.state), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Fortschritt")
        .accessibilityValue("\(Int(progress * 100)) Prozent")
    }

    /// Wiedergabe ist die Hauptaktion und deshalb hervorgehoben.
    private var primaryButton: some View {
        Button(action: onTogglePause) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.body.weight(.semibold))
                .frame(width: 46, height: 34)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: Tokens.Radius.chip))
        // Im Schritt-Modus gibt es keine automatische Wiedergabe - die Taste
        // waere sonst sichtbar, aber wirkungslos.
        .disabled(speed == .manual)
        .accessibilityLabel(isPaused ? "Fortsetzen" : "Pausieren")
    }

    private var speedMenu: some View {
        Menu {
            Picker("Tempo", selection: Binding(get: { speed }, set: onSpeedChange)) {
                ForEach(PlaybackController.Speed.allCases) { option in
                    Text(option.menuLabel).tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.needle")
                    .font(.caption2)
                Text(speed.label)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
            }
            .frame(minWidth: 52, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: Tokens.Radius.chip))
        .accessibilityLabel("Tempo, aktuell \(speed.menuLabel)")
    }

    private func iconButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: Tokens.Radius.chip))
        .accessibilityLabel(label)
    }
}
