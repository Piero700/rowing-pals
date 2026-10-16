//
//  RowerPracticeViewModel.swift
//  Rowing Pals
//

import Foundation

/// One practice as its rower sees it (RowerPractice; decisions 39, 68): their answer and reason,
/// check-in on the day, and the coach's mark — this practice's, or the last one in its series.
@MainActor
@Observable
final class RowerPracticeViewModel {
    let practiceId: UUID

    private(set) var practice: Practice?
    private(set) var answer: PracticeAnswer?
    private(set) var checkedInAt: Date?
    var reason = ""
    private(set) var savedReason = ""
    private(set) var setByName: String?
    /// The coach's mark, and whether it's from an earlier practice in the series.
    private(set) var mark: AttendanceMark?
    private(set) var markIsFromLastPractice = false
    private(set) var markedByName: String?
    private(set) var isSaving = false
    var errorMessage: String?
    private(set) var weekStart: WeekStart = .monday

    init(practiceId: UUID) {
        self.practiceId = practiceId
    }

    var calendar: Calendar { weekStart.calendar() }
    var canAnswer: Bool { practice.map { CalendarRules.canAnswer($0, now: Date()) } ?? false }
    var canCheckIn: Bool { practice.map { CalendarRules.canCheckIn($0, now: Date()) } ?? false && checkedInAt == nil }
    var reasonChanged: Bool { reason.trimmingCharacters(in: .whitespacesAndNewlines) != savedReason }

    func load() async {
        weekStart = await CalendarService.weekStart()
        do {
            let practice = try await CalendarService.practice(practiceId)
            self.practice = practice
            let me = try await ViewerContext.shared.current().userId
            let mine = try await CalendarService.responses(toPractices: [practiceId]).first { $0.userId == me }
            answer = mine?.answer
            checkedInAt = mine?.checkedInAt
            savedReason = mine?.reason ?? ""
            reason = savedReason
            setByName = await name(of: practice.createdBy)
            var marks = try await CalendarService.marks(forPractices: [practiceId]).filter { $0.userId == me }
            markIsFromLastPractice = false
            if marks.isEmpty, let previous = try await CalendarService.previousInSeries(practice) {
                marks = try await CalendarService.marks(forPractices: [previous.id]).filter { $0.userId == me }
                markIsFromLastPractice = !marks.isEmpty
            }
            mark = marks.first
            markedByName = await name(of: mark?.setBy)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load this practice. \(error.localizedDescription)"
        }
    }

    func setAnswer(_ new: PracticeAnswer) async {
        let old = answer
        answer = new
        await save(answer: new, reason: new == .cant ? reason : nil, onFailure: { self.answer = old })
    }

    func saveReason() async {
        await save(answer: .cant, reason: reason, onFailure: {})
        if errorMessage == nil { savedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func checkIn() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await CalendarService.checkIn(to: practiceId)
            checkedInAt = Date()
            answer = .going
            NotificationCenter.default.post(name: .practiceAnswered, object: nil)
        } catch {
            errorMessage = "Couldn’t check in. \(error.localizedDescription)"
        }
    }

    private func save(answer: PracticeAnswer, reason: String?, onFailure: () -> Void) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await CalendarService.respond(to: practiceId, answer: answer, reason: reason)
            errorMessage = nil
            NotificationCenter.default.post(name: .practiceAnswered, object: nil)
        } catch {
            onFailure()
            errorMessage = "Couldn’t save that. \(error.localizedDescription)"
        }
    }

    private func name(of userId: UUID?) async -> String? {
        guard let userId else { return nil }
        return try? await CalendarService.displayName(of: userId)
    }
}
