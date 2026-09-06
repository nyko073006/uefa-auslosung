// SeedFieldView.swift
//
// Der Seed macht einen Lauf reproduzierbar - Voraussetzung fuer den Replay
// und fuer das Erfolgskriterium "gleicher Seed erzeugt gleiche Ergebnisse".

import SwiftUI

struct SeedFieldView: View {

    @Binding var seedText: String
    let isValid: Bool
    let onRandomize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            HStack(spacing: Tokens.Spacing.small) {
                TextField("Seed", text: $seedText)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.white)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif

                Button(action: onRandomize) {
                    Image(systemName: "die.face.5")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Neuen Seed würfeln")
            }

            if !isValid {
                Text("Bitte eine ganze Zahl eingeben.")
                    .font(.caption)
                    .foregroundStyle(Tokens.Brand.magenta)
            }
        }
    }
}
