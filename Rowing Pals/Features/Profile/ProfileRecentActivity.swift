//
//  ProfileRecentActivity.swift
//  Rowing Pals
//

import SwiftUI

/// Profile's most recent workout: "Label · distance" over "time · View workout"; opens the post.
struct ProfileRecentActivity: View {
    let session: ProfileViewModel.ProfilePhoto
    @Environment(\.navigate) private var navigate

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.workoutLink, style: .continuous)

    var body: some View {
        Button {
            navigate(.post(session.id))
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(session.workoutLabel ?? "Training") · \(session.distanceM.formattedMetres)")
                        .textStyle(Typography.rowTitle)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("\(session.totalTimeMs.formattedDurationMs) · View workout")
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                Spacer(minLength: 0)
                RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
            }
            .padding(Tokens.Spacing.card)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(Self.shape.fill(Tokens.Surface.card))
            .overlay { Self.shape.strokeBorder(Tokens.Surface.line, lineWidth: Tokens.Grouped.hairline) }
            .contentShape(Self.shape)
        }
        .buttonStyle(IconPressStyle())
    }
}
