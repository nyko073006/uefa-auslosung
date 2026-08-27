// RejectionBanner.swift
//
// Der Moment, der die Auslosung erklaert.
//
// Der Begruendungstext wird woertlich aus dem Engine-Trace uebernommen. Die App
// formuliert ihn nicht und prueft die Regel nicht nach - sie stellt sie nur dar.

import SwiftUI

struct RejectionBanner: View {

    let candidate: Team
    let reason: String

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.small) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                Text("\(candidate.name) nicht moeglich")
                    .font(.subheadline.weight(.semibold))
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.medium)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip)
                .fill(.orange.opacity(0.12))
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}
