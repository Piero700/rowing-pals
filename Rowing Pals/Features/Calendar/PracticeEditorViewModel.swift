//
//  PracticeEditorViewModel.swift
//  Rowing Pals
//

import Foundation

/// New or Edit practice (CoachPracticeNew; decisions 39, 68): what, when, where, the squads it's
/// for (none means the whole club), every week until a day, and the two-hour reminder. An existing
/// practice in a series saves for itself or for it and the rest of the series; it can be cancelled
/// the same two ways.
@MainActor
@Observable
final class PracticeEditorViewModel {
    let practiceId: UUID?

    var title = ""
    var place = ""
    var day: Date
    var startTime: Date
    var endTime: Date
    var squadIds: Set<UUID> = []
    var repeats = false
    var repeatUntil: Date
    var remind = true

    private(set) var existing: Practice?
    private(set) var squads: [Squad] = []
    private(set) var rowingMemberCount = 0
    private(set) var isSaving = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    /// Quick picks for what the session is.
    static let titles = ["Water", "Erg", "Circuits", "Weights", "Land training"]

    init(practiceId: UUID?, day: Date?, calendar: Calendar = .current) {
        self.practiceId = practiceId
        let start = calendar.startOfDay(for: day ?? Date())
        self.day = start
        self.startTime = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: start) ?? start
        self.endTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: start) ?? start
        self.repeatUntil = calendar.date(byAdding: .weekOfYear, value: 8, to: start) ?? start
        hasLoaded = practiceId == nil
    }

    var isNew: Bool { practiceId == nil }
    var isSeries: Bool { existing?.seriesId != nil }

    private var calendar: Calendar { .current }

    var startsAt: Date { combine(day, startTime) }
    var endsAt: Date { combine(day, endTime) }

    /// "On Tuesdays".
    var repeatDayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE"
        return "On \(formatter.string(from: day))s"
    }

    /// Everyone it's for, as near as the editor can tell before saving.
    var audienceCount: Int {
        if squadIds.isEmpty { return rowingMemberCount }
        return squads.filter { squadIds.contains($0.id) }.reduce(into: Set<UUID>()) { $0.formUnion($1.memberIds) }.count
    }

    var problem: String? {
        if endsAt <= startsAt { return "It has to end after it starts." }
        if isNew && repeats && calendar.startOfDay(for: repeatUntil) < day { return "Repeat until a day on or after the first practice." }
        return nil
    }

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            if let clubId = viewer.clubId { squads = try await CoachingService.squads(of: clubId) }
            rowingMemberCount = viewer.clubmateIds.filter { !viewer.nonRowerIds.contains($0) }.count
            if let practiceId {
                let practice = try await CalendarService.practice(practiceId)
                existing = practice
                title = practice.title ?? ""
                place = practice.place ?? ""
                day = calendar.startOfDay(for: practice.startsAt)
                startTime = practice.startsAt
                endTime = practice.endsAt
                squadIds = Set(practice.squadIds)
                remind = practice.remind
                if let series = practice.seriesId, let last = try? await CalendarService.lastInSeries(series) {
                    repeats = true
                    repeatUntil = calendar.startOfDay(for: last.startsAt)
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load this practice. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    func toggle(_ squad: Squad) {
        if squadIds.contains(squad.id) { squadIds.remove(squad.id) } else { squadIds.insert(squad.id) }
    }

    /// Saves; `restOfSeries` for this and the later practices in its series.
    func save(restOfSeries: Bool = false) async -> Bool {
        guard problem == nil else { return false }
        isSaving = true
        defer { isSaving = false }
        let draft = CalendarService.PracticeDraft(
            title: title, place: place, startsAt: startsAt, endsAt: endsAt, squadIds: squadIds,
            repeatUntil: isNew && repeats ? repeatUntil : nil, remind: remind
        )
        do {
            if let practiceId {
                try await CalendarService.updatePractice(practiceId, restOfSeries: restOfSeries, draft)
            } else {
                try await CalendarService.createPractice(draft)
            }
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t save the practice. \(error.localizedDescription)"
            return false
        }
    }

    func cancelPractice(restOfSeries: Bool) async -> Bool {
        guard let practiceId else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await CalendarService.cancelPractice(practiceId, restOfSeries: restOfSeries)
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t cancel the practice. \(error.localizedDescription)"
            return false
        }
    }

    private func combine(_ day: Date, _ time: Date) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day) ?? day
    }
}
