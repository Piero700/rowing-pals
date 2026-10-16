//
//  EventEditorViewModel.swift
//  Rowing Pals
//

import Foundation

/// New or edit a race or event (CoachRaceNew; decision 68): Race or regatta / Other event, name,
/// first and last day, place, squads (none for the whole club), a note and whether rowers are
/// asked who can race. Adding one tells everyone it's for.
@MainActor
@Observable
final class EventEditorViewModel {
    let eventId: UUID?

    var kind: EventKind
    var name = ""
    var firstDay: Date
    var lastDay: Date
    var isOneDay = true
    var place = ""
    var note = ""
    var asksAvailability = true
    var squadIds: Set<UUID> = []

    private(set) var squads: [Squad] = []
    private(set) var rowingMemberCount = 0
    private(set) var isSaving = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    private var calendar: Calendar { .current }

    init(eventId: UUID?, kind: EventKind = .race, day: Date? = nil) {
        self.eventId = eventId
        self.kind = kind
        let start = Calendar.current.startOfDay(for: day ?? Date())
        firstDay = start
        lastDay = start
        hasLoaded = eventId == nil
    }

    var isNew: Bool { eventId == nil }
    var isRace: Bool { kind == .race }

    var audienceCount: Int {
        if squadIds.isEmpty { return rowingMemberCount }
        return squads.filter { squadIds.contains($0.id) }.reduce(into: Set<UUID>()) { $0.formUnion($1.memberIds) }.count
    }

    var problem: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give it a name." }
        if !isOneDay && calendar.startOfDay(for: lastDay) < calendar.startOfDay(for: firstDay) { return "The last day can’t be before the first." }
        return nil
    }

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            if let clubId = viewer.clubId { squads = try await CoachingService.squads(of: clubId) }
            rowingMemberCount = viewer.clubmateIds.filter { !viewer.nonRowerIds.contains($0) }.count
            if let eventId {
                let event = try await CalendarService.event(eventId)
                kind = event.kind
                name = event.name
                firstDay = WorkoutRules.day(event.firstDay, calendar: calendar) ?? firstDay
                lastDay = WorkoutRules.day(event.lastDay, calendar: calendar) ?? firstDay
                isOneDay = event.firstDay == event.lastDay
                place = event.place ?? ""
                note = event.note ?? ""
                asksAvailability = event.asksAvailability
                squadIds = Set(event.squadIds)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load this. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    func toggle(_ squad: Squad) {
        if squadIds.contains(squad.id) { squadIds.remove(squad.id) } else { squadIds.insert(squad.id) }
    }

    func save() async -> Bool {
        guard problem == nil else { return false }
        isSaving = true
        defer { isSaving = false }
        let draft = CalendarService.EventDraft(
            kind: kind, name: name, firstDay: firstDay, lastDay: isOneDay ? firstDay : lastDay,
            place: place, note: note, asksAvailability: asksAvailability, squadIds: squadIds
        )
        do {
            try await CalendarService.saveEvent(id: eventId, draft)
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t save it. \(error.localizedDescription)"
            return false
        }
    }

    func delete() async -> Bool {
        guard let eventId else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await CalendarService.deleteEvent(eventId)
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t delete it. \(error.localizedDescription)"
            return false
        }
    }
}
