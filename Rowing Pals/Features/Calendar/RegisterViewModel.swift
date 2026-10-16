//
//  RegisterViewModel.swift
//  Rowing Pals
//

import Foundation

/// The register for one practice (CoachPracticeRegister; decision 39): everyone it's for, what
/// each said and did, and the coach's Present · Late · Absent · Excused. Rows the coach hasn't
/// saved start on a mark from the rower's answer, check-in or a session posted that day; saving
/// keeps every row with a mark, and the coach's mark counts over the rower's own answer.
@MainActor
@Observable
final class RegisterViewModel {
    struct Row: Identifiable, Equatable {
        let member: ClubMember
        let line: String
        /// Started on a mark from a session posted that day, not yet saved.
        let isSuggested: Bool
        /// "You changed Present → Late at 17:45".
        let changeLine: String?
        var id: UUID { member.id }
    }

    let practiceId: UUID

    private(set) var practice: Practice?
    private(set) var squadText = ""
    private(set) var rows: [Row] = []
    var marks: [UUID: RegisterMark] = [:]
    private var savedMarks: [UUID: RegisterMark] = [:]
    private(set) var isLoading = false
    private(set) var isSaving = false
    var errorMessage: String?

    private var calendar: Calendar { .current }

    init(practiceId: UUID) {
        self.practiceId = practiceId
    }

    /// "Fri 16 Oct · 17:30–19:00 · Erg room".
    var whenText: String {
        guard let practice else { return "" }
        var parts = [CalendarRules.dayLabel(practice.startsAt, calendar: calendar),
                     "\(CalendarRules.time(practice.startsAt, calendar: calendar))–\(CalendarRules.time(practice.endsAt, calendar: calendar))"]
        if let place = practice.place { parts.append(place) }
        return parts.joined(separator: " · ")
    }

    func count(of mark: RegisterMark) -> Int {
        rows.filter { marks[$0.id] == mark }.count
    }

    var hasChanges: Bool { marks != savedMarks }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let practiceTask = CalendarService.practice(practiceId)
            async let audienceTask = CalendarService.audiences(ofPractices: [practiceId])
            async let responsesTask = CalendarService.responses(toPractices: [practiceId])
            async let marksTask = CalendarService.marks(forPractices: [practiceId])
            async let logTask = CalendarService.markLog(forPractice: practiceId)
            async let membersTask = CalendarService.members()
            let (practice, audiences, responses, saved, log, members) =
                try await (practiceTask, audienceTask, responsesTask, marksTask, logTask, membersTask)
            self.practice = practice

            let viewer = try await ViewerContext.shared.current()
            if practice.squadIds.isEmpty {
                squadText = "Whole club"
            } else if let clubId = viewer.clubId {
                let squads = try await CoachingService.squads(of: clubId)
                squadText = squads.filter { practice.squadIds.contains($0.id) }.map(\.name).joined(separator: ", ")
            }

            let audience = audiences[practiceId] ?? []
            // Anyone marked before they left the squad stays on the register.
            let everyone = audience.union(saved.map(\.userId))
            let shown = members.filter { everyone.contains($0.id) }
            let posted = try await CalendarService.postedSessions(onDay: practice.startsAt, among: shown.map(\.id))
            let byUser = Dictionary(responses.map { ($0.userId, $0) }, uniquingKeysWith: { first, _ in first })
            let savedByUser = Dictionary(saved.map { ($0.userId, $0.mark) }, uniquingKeysWith: { first, _ in first })
            let logByUser = Dictionary(grouping: log, by: \.userId)

            var names: [UUID: String] = [viewer.userId: "You"]
            var starting: [UUID: RegisterMark] = [:]
            var built: [Row] = []
            for member in shown {
                let response = byUser[member.id]
                let didPost = posted.contains(member.id)
                let start = CalendarRules.startingMark(answer: response?.answer, checkedIn: response?.checkedInAt != nil, postedSession: didPost)
                if let mark = savedByUser[member.id] ?? start.mark { starting[member.id] = mark }
                var changeLine: String?
                if let change = CalendarRules.lastChange(logByUser[member.id] ?? []) {
                    let setter = await name(of: change.to.setBy, cache: &names)
                    changeLine = "\(setter) changed \(change.from.label) → \(change.to.mark.label) at \(CalendarRules.time(change.to.setAt, calendar: calendar))"
                }
                built.append(Row(
                    member: member,
                    line: CalendarRules.registerLine(answer: response?.answer, reason: response?.reason,
                                                     checkedInAt: response?.checkedInAt, postedSession: didPost, calendar: calendar),
                    isSuggested: savedByUser[member.id] == nil && start.isSuggested,
                    changeLine: changeLine
                ))
            }
            rows = built
            marks = starting
            savedMarks = savedByUser
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the register. \(error.localizedDescription)"
        }
    }

    func set(_ mark: RegisterMark, for userId: UUID) {
        marks[userId] = mark
    }

    /// Saves every row's mark; a row with none stays unmarked.
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        var changes: [UUID: RegisterMark?] = [:]
        for row in rows {
            let mark = marks[row.id]
            if mark != savedMarks[row.id] { changes[row.id] = mark }
        }
        // A suggested mark the coach left alone is saved too: Save means "this register is right".
        for row in rows where row.isSuggested && changes[row.id] == nil {
            changes[row.id] = marks[row.id]
        }
        guard !changes.isEmpty else { return true }
        do {
            try await CalendarService.setMarks(changes, forPractice: practiceId)
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t save the register. \(error.localizedDescription)"
            return false
        }
    }

    private func name(of userId: UUID?, cache: inout [UUID: String]) async -> String {
        guard let userId else { return "A coach" }
        if let known = cache[userId] { return known }
        let name = (try? await CalendarService.displayName(of: userId)) ?? "A coach"
        cache[userId] = name
        return name
    }
}
