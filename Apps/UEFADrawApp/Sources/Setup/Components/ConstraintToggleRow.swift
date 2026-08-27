// ConstraintToggleRow.swift
//
// Zeigt eine von der Engine deklarierte Regel als Schalter.
// Titel und Erklaerung stammen aus dem `ConstraintDescriptor` - die App kennt
// den Inhalt der Regel nicht und formuliert ihn nicht.

import SwiftUI

struct ConstraintToggleRow: View {

    let descriptor: ConstraintDescriptor
    let isOn: Bool
    let onChange: @MainActor @Sendable (Bool) -> Void

    var body: some View {
        Toggle(
            isOn: Binding(get: { isOn }, set: onChange)
        ) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                Text(descriptor.title)
                Text(descriptor.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
