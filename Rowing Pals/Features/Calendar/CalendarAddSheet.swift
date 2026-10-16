//
//  CalendarAddSheet.swift
//  Rowing Pals
//

import SwiftUI

/// Add on a day of the coach's Calendar (CoachCalendarAdd; decision 68): a practice, a land
/// session, a water session, a race or regatta, or another event.
struct CalendarAddSheet: View {
    let day: Date
    let calendar: Calendar
    let onChoose: (AppRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    /// The options' own height, so the sheet shows all four without scrolling.
    @State private var contentHeight: CGFloat = 480

    private static let rowShape = RoundedRectangle(cornerRadius: Tokens.Radius.panel, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            HStack {
                Text("Add to \(CalendarRules.dayLabel(day, calendar: calendar))")
                    .textStyle(Typography.selectedValue)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                Button("Cancel") { dismiss() }
                    .buttonStyle(.rpText)
            }
            .padding(.bottom, 4)
            option("calendar", "Practice", "A time and place for squads. Can repeat every week, and rowers say if they can come.",
                   .newPractice(day))
            option("stopwatch", "Land session", "An erg workout with pieces and target splits.", .newWorkoutOn(day))
            option("water.waves", "Water session", "The plan, then crew the boats from who’s available.",
                   .newWaterSession(WaterSessionSeed(day: day)))
            option("flag", "Race or regatta", "Rowers say if they can race. Crew the boats when you know.", .newEvent(.race, day))
            option("clock", "Other event", "A meeting, social or kit day. Shows in everyone’s calendar.", .newEvent(.event, day))
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
