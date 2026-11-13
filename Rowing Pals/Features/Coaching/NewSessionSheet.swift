//
//  NewSessionSheet.swift
//  Rowing Pals
//

import SwiftUI

/// The coach bar's + (CoachNew; decisions 67, 75, 91): a land session — an erg workout — a water
/// session, crewed seat by seat, an announcement to every rower, a challenge or an erg event.
/// Practices, races and events come from the Calendar.
struct NewSessionSheet: View {
    let onChoose: (AppRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 520


    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            HStack {
                Text("New")
                    .textStyle(Typography.selectedValue)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                Button("Cancel") { dismiss() }
                    .buttonStyle(.rpText)
            }
            .padding(.bottom, 4)
            GroupedSection {
                option(.stopwatch, "Land session",
                       "An erg workout: pieces, rates and target splits. It goes to your rowers’ Feeds and shows in Workouts.",
                       .newWorkout)
                GroupedDivider()
                option(.water, "Water session",
                       "On the river: the plan, then crew the boats seat by seat. Each rower is told their boat and seat; it shows in Boats.",
                       .newWaterSession(WaterSessionSeed()))
                GroupedDivider()
                option(.megaphone, "Announcement",
                       "A notice for every rower. Its heading sits at the top of their Feed; they tap it to read the rest.",
                       .newAnnouncement)
                GroupedDivider()
                option(.rankings, "Challenge",
                       "A personal target, a club total or squad against squad, on erg metres between two days. It shows in Rankings and on rowers’ Feeds.",
                       .newChallenge)
                GroupedDivider()
                option(.flag, "Erg event",
                       "A set piece rowed in a window, like a club 2k day. Everyone’s best goes on one board.",
                       .newErgEvent)
            }
            Text("Practices, races and other events are added from the Calendar. Announcements, challenges and erg events are kept in the Calendar too.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 4)
                .guidance()
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

    private func option(_ symbol: RPIcon, _ title: String, _ detail: String, _ route: AppRoute) -> some View {
        Button {
            onChoose(route)
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                RPIconView(icon: symbol, size: Tokens.Icon.large)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Size.rowIcon, height: Tokens.Size.rowIcon)
                    .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(detail)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .multilineTextAlignment(.leading)
                        .guidance()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RPIconView(icon: .chevronRight, size: Tokens.Icon.small)
                    .textStyle(Typography.pill)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, Tokens.Grouped.rowPadding)
            .padding(.vertical, Tokens.Spacing.tight)
            .frame(minHeight: Tokens.Grouped.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
    }
}
