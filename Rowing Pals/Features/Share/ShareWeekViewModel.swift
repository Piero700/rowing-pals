//
//  ShareWeekViewModel.swift
//  Rowing Pals
//

import SwiftUI

/// The Share week / Share workout sheet (decision 110): loads what the picture needs, works out
/// its heading, dates and rows, and draws it.
@MainActor
@Observable
final class ShareWeekViewModel {
    enum Mode: Equatable {
        case week
        case workout(UUID)
    }

    enum Which: Equatable {
        case thisWeek, nextWeek

        var label: String { self == .thisWeek ? "This week" : "Next week" }
    }

    let mode: Mode
    var which: Which = .thisWeek
    var audience: ShareAudience = .club
    private(set) var squads: [Squad] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private var practices: [Practice] = []
    private var workouts: [CoachWorkout] = []
    private var water: [WaterSession] = []
    private var events: [ClubEvent] = []
    private var clubName = "Your club"
    private var today = Date()
    private var weekStart: WeekStart = .monday
    private var calendar: Calendar

    init(mode: Mode) {
        self.mode = mode
        calendar = WeekStart.monday.calendar()
    }

    /// With everything already loaded, for tests.
    init(mode: Mode, practices: [Practice], workouts: [CoachWorkout], water: [WaterSession],
         events: [ClubEvent], squads: [Squad], clubName: String, today: Date, weekStart: WeekStart,
         calendar: Calendar? = nil) {
        self.mode = mode
        self.practices = practices
        self.workouts = workouts
        self.water = water
        self.events = events
        self.squads = squads
        self.clubName = clubName
        self.today = today
        self.weekStart = weekStart
        self.calendar = calendar ?? weekStart.calendar()
    }

    /// "Whole club", or the chosen squad's name.
    var audienceLabel: String {
        if case .squad(let id) = audience, let squad = squads.first(where: { $0.id == id }) { return squad.name }
        return "Whole club"
    }

    var isWeek: Bool { mode == .week }

    var sheetTitle: String { isWeek ? "Share week" : "Share workout" }

    /// The workout in workout mode, once loaded.
    private var workout: CoachWorkout? {
        guard case .workout(let id) = mode else { return nil }
        return workouts.first { $0.id == id }
    }

    /// The week shown: its first day to the next week's first day (exclusive).
    private var range: DateInterval {
        let thisWeek = CalendarRules.weekStart(of: today, calendar: calendar)
        let start = which == .thisWeek ? thisWeek : (calendar.date(byAdding: .day, value: 7, to: thisWeek) ?? thisWeek)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    var heading: String {
        switch mode {
        case .week: which.label
        case .workout: workout?.title ?? "Workout"
        }
    }

    var subheading: String {
        switch mode {
        case .week:
            let who: String
            switch audience {
            case .club: who = clubName
            case .squad(let id): who = squads.first { $0.id == id }?.name ?? clubName
            }
            return "\(who) · \(ShareCardRules.dateRangeText(range, calendar: calendar))"
        case .workout:
            let names = Dictionary(squads.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            return workout.map {
                ShareCardRules.workoutSubheading($0, clubName: clubName, squads: names, calendar: calendar)
            } ?? ""
        }
    }

    var rows: [ShareCardRow] {
        switch mode {
        case .week:
            return ShareCardRules.weekRows(practices: practices, workouts: workouts, water: water,
                                           events: events, audience: audience, range: range, calendar: calendar)
        case .workout:
            return workout.map { ShareCardRules.workoutRows($0) } ?? []
        }
    }

    /// Whether there is something to draw yet.
    var isReady: Bool { isWeek || workout != nil }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch mode {
            case .week: try await loadWeeks()
            case .workout(let id): try await loadWorkout(id)
            }
            errorMessage = nil
        } catch {
            // Closing the sheet mid-load cancels it: that isn't an error to show.
            if Self.isCancellation(error) { return }
            errorMessage = "Couldn’t load it. \(error.localizedDescription)"
        }
    }

    static func isCancellation(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        return false
    }

    /// The workout, with the club's name and squads that name its card.
    private func loadWorkout(_ id: UUID) async throws {
        weekStart = await CalendarService.weekStart()
        calendar = weekStart.calendar()
        let viewer = try await ViewerContext.shared.current()
        clubName = viewer.clubName ?? "Your club"
        async let workoutRow = WorkoutService.workout(id)
        async let squadRows = Self.squads(ofClub: viewer.clubId)
        workouts = [try await workoutRow]
        squads = try await squadRows
    }

    /// This week and next week at once, with the same calls the Calendar makes.
    private func loadWeeks() async throws {
        weekStart = await CalendarService.weekStart()
        calendar = weekStart.calendar()
        today = Date()
        let thisWeek = CalendarRules.weekStart(of: today, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 14, to: thisWeek) ?? thisWeek
        let viewer = try await ViewerContext.shared.current()
        clubName = viewer.clubName ?? "Your club"
        async let practiceRows = CalendarService.clubPractices(from: thisWeek, to: end)
        async let workoutRows = WorkoutService.clubWorkouts()
        async let eventRows = CalendarService.clubEvents(fromDay: WorkoutRules.dayText(thisWeek, calendar: calendar))
        async let waterRows = (try? await BoatService.sessions(from: thisWeek, to: end)) ?? []
        async let squadRows = Self.squads(ofClub: viewer.clubId)
        (practices, workouts, events) = try await (practiceRows, workoutRows, eventRows)
        water = await waterRows
        squads = try await squadRows
        if case .squad(let id) = audience, !squads.contains(where: { $0.id == id }) { audience = .club }
    }

    private static func squads(ofClub clubId: UUID?) async throws -> [Squad] {
        guard let clubId else { return [] }
        return try await CoachingService.squads(of: clubId)
    }

    /// The picture, drawn at 3x (1080 px wide) in the dark palette.
    func render() -> UIImage? {
        guard isReady else { return nil }
        let renderer = ImageRenderer(content: ShareWeekCardView(heading: heading, subheading: subheading, rows: rows))
        renderer.scale = 3
        return renderer.uiImage
    }
}
