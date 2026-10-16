//
//  NewSessionSheet.swift
//  Rowing Pals
//

import SwiftUI

/// The coach bar's + (CoachNew; decision 67): a land session — an erg workout — or a water
/// session, crewed seat by seat. Practices, races and events come from the Calendar.
struct NewSessionSheet: View {
    let onChoose: (AppRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 420

    private static let rowShape = RoundedRectangle(cornerRadius: Tokens.Radius.panel, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            HStack {
                Text("New session")
                    .textStyle(Typography.selectedValue)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                Button("Cancel") { dismiss() }
                    .buttonStyle(.rpText)
            }
            .padding(.bottom, 4)
            option("stopwatch", "Land session",
                   "An erg workout: pieces, rates and target splits. It goes to your rowers’ Feeds and shows in Workouts.",
                   .newWorkout)
            option("water.waves", "Water session",
                   "On the river: the plan, then crew the boats seat by seat. Each rower is told their boat and seat; it shows in Boats.",
                   .newWaterSession(WaterSessionSeed()))
            Text("Practices, races and other events are added from the Calendar.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 4)
        }
        .padding(.horizontal, Tokens.Spacing.screen)
        .padding(.top, Tokens.Spacing.group)
        .padding(.bottom, Tokens.Spacing.loose)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Tokens.Base.ground)
    }

    private func option(_ symbol: String, _ title: String, _ detail: String, _ route: AppRoute) -> some View {
        Button {
            onChoose(route)
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                Image(systemName: symbol)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Schedule.iconTile, height: Tokens.Schedule.iconTile)
                    .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(detail)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(Tokens.Spacing.loose)
            .background(Self.rowShape.fill(Tokens.Surface.card))
            .overlay { Self.rowShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.rowShape)
        }
        .buttonStyle(IconPressStyle())
    }
}
