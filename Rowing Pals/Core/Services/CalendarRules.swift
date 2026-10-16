//
//  CalendarRules.swift
//  Rowing Pals
//

import Foundation

/// The Calendar's arithmetic (decisions 39, 68, 69), kept free of the network so it can be tested:
/// the club's weeks and months, a day's whole-day answer, when answers and check-in are open,
/// a practice's counts for its coach, and attendance totals.
enum CalendarRules {
    // MARK: - Weeks and months

    /// The first day of the week holding `date`, in a calendar whose `firstWeekday` is the club's.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let back = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -back, to: day) ?? day
    }

    /// The seven days of the week starting `start`.
    static func days(ofWeekStarting start: Date, calendar: Calendar) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// A month as the coach's Calendar draws it: whole weeks from the club's first weekday, with
    /// nil for the days before the 1st and after the last.
    static func monthGrid(containing date: Date, calendar: Calendar) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let first = calendar.startOfDay(for: interval.start)
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var grid: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<days.count {
            grid.append(calendar.date(byAdding: .day, value: offset, to: first))
        }
        while grid.count % 7 != 0 { grid.append(nil) }
        return grid
    }

    /// The weekday letters along the top of the month, starting on the club's day.
    static func weekdayInitials(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    // MARK: - A rower's answers

    /// Answers can change until the practice starts; a cancelled one takes none.
    static func canAnswer(_ practice: Practice, now: Date) -> Bool {
        !practice.cancelled && now < practice.startsAt
    }

    /// Check-in opens 30 minutes before the start and closes at the end.
    static func canCheckIn(_ practice: Practice, now: Date) -> Bool {
        !practice.cancelled && now >= practice.startsAt.addingTimeInterval(-30 * 60) && now <= practice.endsAt
    }

    /// The Whole day control: Available or Can't when every session that day has that answer,
    /// otherwise neither.
    static func wholeDay(_ answers: [PracticeAnswer?]) -> PracticeAnswer? {
        guard let first = answers.first, let answer = first, answers.allSatisfy({ $0 == answer }) else { return nil }
        return answer
    }

    /// The line under Whole day: "Both sessions", "Evening only", "Can't make it", "Not answered"…
    /// `sessions` are that day's practices in time order with the rower's answer to each.
    static func daySummary(_ sessions: [(practice: Practice, answer: PracticeAnswer?)], calendar: Calendar) -> String {
        let answers = sessions.map(\.answer)
        let answered = answers.compactMap { $0 }
        if answered.isEmpty { return "Not answered" }
        if answered.count < answers.count { return "\(answered.count) of \(answers.count) answered" }
        let going = sessions.filter { $0.answer == .going }
        if going.isEmpty { return "Can’t make it" }
        if going.count == sessions.count {
            switch sessions.count {
            case 1: return "Available"
            case 2: return "Both sessions"
            default: return "All \(sessions.count) sessions"
            }
        }
        if going.count == 1, sessions.count == 2 {
            return calendar.component(.hour, from: going[0].practice.startsAt) < 12 ? "Morning only" : "Evening only"
        }
        return "\(going.count) of \(sessions.count) sessions"
    }

    /// "Available for the other N": the practices still open to an answer that have none yet.
    static func unanswered(_ practices: [Practice], answers: [UUID: PracticeAnswer], now: Date) -> [Practice] {
        practices.filter { canAnswer($0, now: now) && answers[$0.id] == nil }
    }

    // MARK: - The coach's view of a practice

    struct Counts: Equatable {
        var available = 0
        var cant = 0
        var noAnswer = 0
    }

    /// Available, Can't and no answer among everyone a practice is for.
    static func counts(audience: Set<UUID>, responses: [PracticeResponse]) -> Counts {
        let byUser = Dictionary(responses.map { ($0.userId, $0.answer) }, uniquingKeysWith: { first, _ in first })
        var counts = Counts()
        for user in audience {
            switch byUser[user] ?? nil {
            case .going: counts.available += 1
            case .cant: counts.cant += 1
            case nil: counts.noAnswer += 1
            }
        }
        return counts
    }

    /// "every Friday" for a practice in a weekly series; nil for a one-off.
    static func repeatCaption(_ practice: Practice, calendar: Calendar) -> String? {
        guard practice.seriesId != nil else { return nil }
        return "every \(formatter("EEEE", calendar: calendar).string(from: practice.startsAt))"
    }

    // MARK: - Attendance totals

    struct Totals: Equatable {
        var attended = 0
        var counted = 0

        /// Nil with nothing counted yet.
        var share: Double? { counted == 0 ? nil : Double(attended) / Double(counted) }

        /// "86%", or nil.
        var percentText: String? { share.map { "\(Int(($0 * 100).rounded()))%" } }
    }

    /// Present and Late count as attended; Excused is left out (decision 39).
    static func totals(_ marks: [RegisterMark]) -> Totals {
        marks.reduce(into: Totals()) { totals, mark in
            guard mark.counted else { return }
            totals.counted += 1
            if mark.attended { totals.attended += 1 }
        }
    }

    // MARK: - Events

    /// Whether a race or event covers `day` ("yyyy-MM-dd" strings compare in order).
    static func event(_ event: ClubEvent, covers day: String) -> Bool {
        event.firstDay <= day && day <= event.lastDay
    }

    /// "Sat 31 Oct", or "Sat 31 Oct – Sun 1 Nov" for more than one day.
    static func eventDays(_ event: ClubEvent, calendar: Calendar) -> String {
        guard let first = WorkoutRules.day(event.firstDay, calendar: calendar) else { return event.firstDay }
        guard event.lastDay != event.firstDay, let last = WorkoutRules.day(event.lastDay, calendar: calendar) else {
            return dayLabel(first, calendar: calendar)
        }
        return "\(dayLabel(first, calendar: calendar)) – \(dayLabel(last, calendar: calendar))"
    }

    // MARK: - Text

    /// "Fri 16 Oct".
    static func dayLabel(_ date: Date, calendar: Calendar) -> String {
        formatter("EEE d MMM", calendar: calendar).string(from: date)
    }

    /// "06:30".
    static func time(_ date: Date, calendar: Calendar) -> String {
        formatter("HH:mm", calendar: calendar).string(from: date)
    }

    /// "October 2026".
    static func monthTitle(_ date: Date, calendar: Calendar) -> String {
        formatter("MMMM yyyy", calendar: calendar).string(from: date)
    }

    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = format
        return formatter
    }
}
