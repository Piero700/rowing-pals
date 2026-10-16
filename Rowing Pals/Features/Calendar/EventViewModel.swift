//
//  EventViewModel.swift
//  Rowing Pals
//

import Foundation

/// One race or event (CoachRace; decision 68). A coach sees who can race, who can't (with
/// reasons) and who hasn't answered, and can edit it; a rower it's for answers Can you race? with
/// a reason only coaches see.
@MainActor
@Observable
final class EventViewModel {
    let eventId: UUID

    private(set) var event: ClubEvent?
    private(set) var isCoach = false
    private(set) var squadText = ""
    private(set) var counts = CalendarRules.Counts()
    private(set) var canRace: [AnswerListCard.Person] = []
    private(set) var cantRace: [AnswerListCard.Person] = []
    private(set) var noAnswer: [AnswerListCard.Person] = []

    /// The rower's own answer.
    private(set) var myAnswer: PracticeAnswer?
    var reason = ""
    private var savedReason = ""
    private(set) var isSaving = false
    var errorMessage: String?

    var calendar: Calendar { .current }

    init(eventId: UUID) {
        self.eventId = eventId
    }

    var isRace: Bool { event?.kind == .race }
    var reasonChanged: Bool { reason != savedReason }

    /// "Sat 31 Oct · River Wensum · Senior men, Senior women, Novices".
    var detailLine: String {
        guard let event else { return "" }
        return [CalendarRules.eventDays(event, calendar: calendar), event.place, squadText].compactMap { $0 }.joined(separator: " · ")
    }

    /// Answers close once the last day has passed.
    var canAnswer: Bool {
        guard let event else { return false }
        return event.lastDay >= WorkoutRules.dayText(calendar.startOfDay(for: Date()), calendar: calendar)
    }

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            isCoach = viewer.isCoach
            let event = try await CalendarService.event(eventId)
            self.event = event
            if event.squadIds.isEmpty {
                squadText = "Whole club"
            } else if let clubId = viewer.clubId, let squads = try? await CoachingService.squads(of: clubId) {
                let names = squads.filter { event.squadIds.contains($0.id) }.map(\.name)
                squadText = names.isEmpty ? "Squads" : names.joined(separator: ", ")
            }
            let responses = try await CalendarService.eventResponses([eventId])
            if isCoach {
                async let audiencesTask = CalendarService.audiences(ofEvents: [eventId])
                async let membersTask = CalendarService.members()
                let (audiences, members) = try await (audiencesTask, membersTask)
                let audience = audiences[eventId] ?? []
                counts = CalendarRules.counts(audience: audience, eventResponses: responses)
                let byUser = Dictionary(responses.map { ($0.userId, $0) }, uniquingKeysWith: { first, _ in first })
                var yes: [AnswerListCard.Person] = []
                var no: [AnswerListCard.Person] = []
                var none: [AnswerListCard.Person] = []
                for member in members where audience.contains(member.id) {
                    switch byUser[member.id]?.canCome {
                    case true?: yes.append(.init(member: member, detail: member.side?.label))
                    case false?: no.append(.init(member: member, detail: byUser[member.id]?.reason.map { "“\($0)”" }))
                    case nil: none.append(.init(member: member, detail: nil))
                    }
                }
                (canRace, cantRace, noAnswer) = (yes, no, none)
            } else if let mine = responses.first(where: { $0.userId == viewer.userId }) {
                myAnswer = mine.canCome ? .going : .cant
                reason = mine.reason ?? ""
                savedReason = reason
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load this \(isRace ? "race" : "event"). \(error.localizedDescription)"
        }
    }

    func setAnswer(_ answer: PracticeAnswer) async {
        let old = myAnswer
        myAnswer = answer
        isSaving = true
        defer { isSaving = false }
        do {
            try await CalendarService.respond(toEvent: eventId, canCome: answer == .going, reason: answer == .cant ? reason : nil)
            savedReason = answer == .cant ? reason : ""
            NotificationCenter.default.post(name: .practiceAnswered, object: nil)
            errorMessage = nil
        } catch {
            myAnswer = old
            errorMessage = "Couldn’t save that. \(error.localizedDescription)"
        }
    }

    func saveReason() async {
        guard myAnswer == .cant else { return }
        await setAnswer(.cant)
    }
}
