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
        HStack(alignment: .top, spacing: Tokens.Spacing.medium) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Tokens.Brand.deep)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Tokens.Brand.yellow))

            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                Text("\(candidate.name) nicht möglich")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Tokens.Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.medium)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .fill(Tokens.Brand.yellow.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous)
                .strokeBorder(Tokens.Brand.yellow.opacity(0.35), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            // Schmaler Akzent an der Kante - macht den Hinweis scanbar.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Tokens.Brand.yellow)
                .frame(width: 3)
                .padding(.vertical, Tokens.Spacing.small)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.chip, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nicht möglich: \(candidate.name). \(reason)")
    }
}
