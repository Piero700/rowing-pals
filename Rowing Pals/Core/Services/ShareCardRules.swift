//
//  ShareCardRules.swift
//  Rowing Pals
//

import Foundation

/// What goes on the picture a coach shares to WhatsApp (decision 110): the week's rows, one
/// workout's pieces, the date range and the footer.
nonisolated enum ShareCardRules {
    static let footer = "No iPhone? Say if you can make it at rowingpals.com/go"
    static let link = URL(string: "https://rowingpals.com/go")

    // MARK: - Week

    static func weekRows(practices: [Practice], workouts: [CoachWorkout], water: [WaterSession],
                         events: [ClubEvent], audience: ShareAudience, range: DateInterval,
                         calendar: Calendar) -> [ShareCardRow] {
        var rows: [ShareCardRow] = []

        for practice in practices where !practice.cancelled
            && keeps(practice.squadIds, audience) && range.contains(practice.startsAt) {
            rows.append(row(id: "practice-\(practice.id)", start: practice.startsAt, timed: true,
                            title: practice.displayTitle, detail: practice.place, calendar: calendar))
        }

        for workout in workouts where workout.audience != .rowers && keeps(workout, audience) {
            guard let start = WorkoutRules.startDate(workout, calendar: calendar)
                    ?? WorkoutRules.day(workout.workoutDate, calendar: calendar),
                  range.contains(start) else { continue }
            let timed = WorkoutRules.startDate(workout, calendar: calendar) != nil
            let summary = WorkoutRules.piecesSummary(workout.pieces) ?? workout.title
            let extras = [WorkoutRules.rateText(workout.pieces), WorkoutRules.restText(workout.pieces)]
                .compactMap { $0 }
            rows.append(row(id: "workout-\(workout.id)", start: start, timed: timed,
                            title: "Erg · \(summary)",
                            detail: extras.isEmpty ? nil : extras.joined(separator: " · "), calendar: calendar))
        }

        for session in water where range.contains(session.startsAt) && keeps(session, practices, events, audience) {
            rows.append(row(id: "water-\(session.id)", start: session.startsAt, timed: true, title: "Water",
                            detail: session.meetAt.map { "meet \($0)" }, calendar: calendar))
        }

        for event in events where keeps(event.squadIds, audience) {
            guard let first = WorkoutRules.day(event.firstDay, calendar: calendar),
                  let last = WorkoutRules.day(event.lastDay, calendar: calendar) else { continue }
            let begin = max(first, calendar.startOfDay(for: range.start))
            guard begin <= last, range.contains(begin) else { continue }
            rows.append(row(id: "event-\(event.id)", start: begin, timed: false, title: event.name,
                            detail: event.place, calendar: calendar))
        }

        return rows.sorted { $0.start < $1.start }
    }

    /// "24–30 Nov", or across months "28 Nov – 4 Dec". The range's end is exclusive, as a week's is.
    static func dateRangeText(_ range: DateInterval, calendar: Calendar) -> String {
        let first = range.start
        let last = range.end > range.start ? range.end.addingTimeInterval(-1) : range.start
        let a = calendar.dateComponents([.day, .month, .year], from: first)
        let b = calendar.dateComponents([.day, .month, .year], from: last)
        let month = monthShort(last, calendar)
        if a.month == b.month && a.year == b.year {
            if a.day == b.day { return "\(b.day ?? 0) \(month)" }
            return "\(a.day ?? 0)–\(b.day ?? 0) \(month)"
        }
        return "\(a.day ?? 0) \(monthShort(first, calendar)) – \(b.day ?? 0) \(month)"
    }

    // MARK: - Workout

    /// One row per piece.
    static func workoutRows(_ workout: CoachWorkout) -> [ShareCardRow] {
        workout.pieces.enumerated().map { index, piece in
            ShareCardRow(id: "piece-\(index)", start: .distantPast, dayText: "", timeText: nil,
                         title: WorkoutRules.pieceTitle(piece), detail: WorkoutRules.pieceDetail(piece))
        }
    }

    // MARK: - Private

    private static func row(id: String, start: Date, timed: Bool, title: String, detail: String?,
                            calendar: Calendar) -> ShareCardRow {
        ShareCardRow(id: id, start: start,
                     dayText: CalendarRules.weekdayShort(start, calendar: calendar).capitalized,
                     timeText: timed ? CalendarRules.time(start, calendar: calendar) : nil,
                     title: title, detail: detail)
    }

    private static func monthShort(_ date: Date, _ calendar: Calendar) -> String {
        DateFormatterCache.formatter("MMM", calendar: calendar, timeZone: calendar.timeZone, locale: "en_GB")
            .string(from: date)
    }

    private static func keeps(_ squadIds: [UUID], _ audience: ShareAudience) -> Bool {
        switch audience {
        case .club: true
        case .squad(let squad): squadIds.isEmpty || squadIds.contains(squad)
        }
    }

    private static func keeps(_ workout: CoachWorkout, _ audience: ShareAudience) -> Bool {
        switch audience {
        case .club: true
        case .squad(let squad): workout.audience == .club || workout.squadIds.contains(squad)
        }
    }

    private static func keeps(_ session: WaterSession, _ practices: [Practice], _ events: [ClubEvent],
                              _ audience: ShareAudience) -> Bool {
        if let id = session.practiceId, let practice = practices.first(where: { $0.id == id }) {
            return keeps(practice.squadIds, audience)
        }
        if let id = session.eventId, let event = events.first(where: { $0.id == id }) {
            return keeps(event.squadIds, audience)
        }
        return true
    }
}
