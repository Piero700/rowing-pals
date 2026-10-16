//
//  DateBlock.swift
//  Rowing Pals
//

import SwiftUI

/// A day as the Calendar shows it beside its sessions (RowerCalendar, CoachPractices, the Feed's
/// practice card): the weekday's three letters over the day's number, in a raised rounded tile.
struct DateBlock: View {
    let date: Date
    var calendar: Calendar = .current
    /// Greyed, for a day with nothing on.
    var isQuiet = false

    var body: some View {
        VStack(spacing: 0) {
            Text(CalendarRules.weekdayShort(date, calendar: calendar))
                .textStyle(Typography.tag)
            Text("\(calendar.component(.day, from: date))")
                .textStyle(Typography.coachStatSmall)
                .tabularNumerals()
        }
        .foregroundStyle(isQuiet ? Tokens.Ink.secondary : Tokens.Ink.primary)
        .frame(width: Tokens.Schedule.dateBlockWidth, height: Tokens.Schedule.dateBlockHeight)
        .background(RoundedRectangle(cornerRadius: Tokens.Schedule.dateBlockRadius, style: .continuous).fill(Tokens.Surface.raised))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CalendarRules.dayLabel(date, calendar: calendar))
    }
}
