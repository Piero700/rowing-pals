//
//  CoachingViewModel.swift
//  Rowing Pals
//

import Foundation

/// Coaching's Rowers list (CoachRowers, decisions 39 and 43): every rowing member of the club
/// the viewer coaches, filtered to one squad and sorted as chosen.
@Observable
final class CoachingViewModel {
    var roster: CoachingService.Roster?
    /// Each rower's attendance at set workouts over the last 8 weeks (decision 62).
    var attendance: [UUID: WorkoutAttendance] = [:]
    var squad: UUID?
    var sort: RosterSort = .behindTarget
    var isLoading = false
    var errorMessage: String?

    /// The list as shown: the chosen squad, in the chosen order.
    var rowers: [CoachRower] {
        CoachingRules.sorted(CoachingRules.filtered(roster?.rowers ?? [], squad: squad), by: sort, attendance: attendance)
    }

    /// The rowers shown, together: "84% attendance", or nil with nothing set yet.
    var attendanceText: String? {
        WorkoutAttendance.total(rowers.compactMap { attendance[$0.id] }).percent.map { "\($0)%" }
    }

    var squadName: String {
        guard let squad, let found = roster?.squads.first(where: { $0.id == squad }) else { return "All squads" }
        return found.name
    }

    var behindCount: Int { rowers.filter(\.isBehindTarget).count }
    var flaggedCount: Int { rowers.filter { !$0.flags.isEmpty }.count }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let attendanceTask = Self.loadAttendance()
            let fresh = try await CoachingService.roster()
            roster = fresh
            // Attendance is extra: if it can't be read, the list still shows.
            attendance = (try? await attendanceTask) ?? [:]
            // A squad deleted elsewhere drops back to everyone.
            if let squad, !fresh.squads.contains(where: { $0.id == squad }) { self.squad = nil }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The club's set workouts from the last 8 weeks, who they were for and who posted, plus the
    /// registers of the practices in those weeks.
    private static func loadAttendance(calendar: Calendar = .current) async throws -> [UUID: WorkoutAttendance] {
        let today = WorkoutRules.dayText(Date(), calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -7 * 8, to: Date()) ?? Date()
        let since = WorkoutRules.dayText(start, calendar: calendar)
        let workouts = try await WorkoutService.clubWorkouts()
            .filter { $0.workoutDate >= since && $0.workoutDate <= today }
        let ids = workouts.map(\.id)
        async let audiencesTask = WorkoutService.audiences(of: ids)
        async let postedTask = WorkoutService.postings(for: ids)
        let (audiences, posted) = try await (audiencesTask, postedTask)
        let fromWorkouts = CoachingRules.attendance(workouts: workouts, audiences: audiences, posted: posted, since: since, today: today)
        // Practices' registers count too (decision 62); before the calendar migration there are none.
        let practices = ((try? await CalendarService.clubPractices(from: start, to: Date())) ?? [])
            .filter { !$0.cancelled && $0.startsAt <= Date() }
        let marks = (try? await CalendarService.marks(forPractices: practices.map(\.id))) ?? []
        return CoachingRules.addingPractices(marks, to: fromWorkouts)
    }
}
