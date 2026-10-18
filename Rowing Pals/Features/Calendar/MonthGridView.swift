//
//  MonthGridView.swift
//  Rowing Pals
//

import SwiftUI

/// A month in the club's weeks (CoachCalendar; decision 69): arrows either side of its name, the
/// weekday letters, and each day — today ringed, the chosen day filled, past days quieter — with
/// up to two dots for its practices and a flag for a race or event.
struct MonthGridView: View {
    let month: Date
    let grid: [Date?]
    let selected: Date
    let calendar: Calendar
    let dots: (Date) -> Int
    let hasEvent: (Date) -> Bool
    let onSelect: (Date) -> Void
    let onMove: (Int) -> Void

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 0), count: 7) }

    var body: some View {
        VStack(spacing: Tokens.Spacing.tight) {
            HStack {
                GlassIconButton(icon: .chevronLeft, accessibilityLabel: "Previous month") { onMove(-1) }
                Spacer(minLength: 0)
                Text(CalendarRules.monthTitle(month, calendar: calendar))
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                GlassIconButton(icon: .chevronRight, accessibilityLabel: "Next month") { onMove(1) }
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(CalendarRules.weekdayInitials(calendar: calendar).enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .textStyle(Typography.fieldLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                ForEach(Array(grid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        cell(day)
                    } else {
                        Color.clear.frame(height: Tokens.Schedule.dayCell)
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.tight)
        .padding(.vertical, Tokens.Spacing.loose)
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func cell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDateInToday(day)
        let isPast = day < calendar.startOfDay(for: Date())
        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .textStyle(isSelected || isToday ? Typography.rowTitle : Typography.bodySecondary)
                    .tabularNumerals()
                    .foregroundStyle(isSelected ? Tokens.Ink.onBrand : isToday ? Tokens.Accent.brand : isPast ? Tokens.Ink.secondary : Tokens.Ink.primary)
                    .frame(width: Tokens.Schedule.dayNumber, height: Tokens.Schedule.dayNumber)
                    .background {
                        if isSelected {
                            Circle().fill(Tokens.Accent.brand)
                        } else if isToday {
                            Circle().strokeBorder(Tokens.Accent.brand, lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 3) {
                    if hasEvent(day) {
                        // Small, with the canvas's heavier stroke at this size (decision 80).
                        RPIconView(icon: .flag, size: Tokens.Schedule.flag, weight: 2.6)
                            .foregroundStyle(Tokens.Ink.primary)
                    } else {
                        ForEach(0..<dots(day), id: \.self) { _ in
                            Circle().fill(Tokens.Ink.secondary).frame(width: Tokens.Schedule.dot, height: Tokens.Schedule.dot)
                        }
                    }
                }
                .frame(height: Tokens.Schedule.flag)
            }
            .frame(maxWidth: .infinity, minHeight: Tokens.Schedule.dayCell)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(CalendarRules.dayLabel(day, calendar: calendar))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
