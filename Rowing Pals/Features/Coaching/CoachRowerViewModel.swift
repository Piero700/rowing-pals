//
//  CoachRowerViewModel.swift
//  Rowing Pals
//

import Foundation

/// One rower as their coach sees them (CoachRower, decisions 35, 39, 40): read-only.
@Observable
final class CoachRowerViewModel {
    let userId: UUID
    var detail: CoachingService.RowerDetail?
    /// This term's register marks, oldest first (decision 39); empty with none taken.
    var marks: [RegisterMark] = []
    /// "this term", or "last 8 weeks" when the club hasn't set term dates covering today.
    var marksSpan = "this term"
    var isLoading = false
    var errorMessage: String?

    init(userId: UUID) {
        self.userId = userId
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await CoachingService.rower(userId)
            // Attendance is extra: if it can't be read (before the calendar migration), the page still shows.
            await loadMarks()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadMarks(calendar: Calendar = .current) async {
        let today = calendar.startOfDay(for: Date())
        let terms = (try? await CalendarService.terms()) ?? []
        let from: Date
        if let term = CalendarRules.term(containing: WorkoutRules.dayText(today, calendar: calendar), in: terms),
           let start = WorkoutRules.day(term.startsOn, calendar: calendar) {
            from = start
            marksSpan = "this term"
        } else {
            from = calendar.date(byAdding: .day, value: -7 * 8, to: today) ?? today
            marksSpan = "last 8 weeks"
        }
        guard let practices = try? await CalendarService.clubPractices(from: from, to: Date()) else { return }
        let started = practices.filter { !$0.cancelled && $0.startsAt <= Date() }
        let order = Dictionary(uniqueKeysWithValues: started.map { ($0.id, $0.startsAt) })
        guard let all = try? await CalendarService.marks(forPractices: started.map(\.id)) else { return }
        marks = all.filter { $0.userId == userId }
            .sorted { (order[$0.practiceId] ?? .distantPast) < (order[$1.practiceId] ?? .distantPast) }
            .map(\.mark)
    }
}
