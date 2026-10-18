//
//  ErgEventEditorViewModel.swift
//  Rowing Pals
//

import Foundation

/// Set an erg event, or change or delete one (decision 91): its name, the piece — a distance in
/// metres or a time typed like every time in the app — and when it starts and ends.
@MainActor
@Observable
final class ErgEventEditorViewModel {
    let eventId: UUID?

    var title = ""
    var isDistance = true {
        didSet { if isDistance != oldValue { amount = "" } }
    }
    /// Metres as typed, or the time as shown ("20:00").
    var amount = ""
    var startsAt: Date = ErgEventEditorViewModel.nextHour() {
        didSet { if endsAt <= startsAt { endsAt = startsAt.addingTimeInterval(3 * 3600) } }
    }
    var endsAt: Date = ErgEventEditorViewModel.nextHour().addingTimeInterval(3 * 3600)

    private(set) var hasLoaded = false
    private(set) var isSaving = false
    var errorMessage: String?

    init(eventId: UUID?) {
        self.eventId = eventId
    }

    var isNew: Bool { eventId == nil }

    func load() async {
        if let eventId {
            do {
                let event = try await ErgEventService.event(eventId)
                title = event.title
                isDistance = event.distanceM != nil
                amount = event.distanceM.map(String.init)
                    ?? event.durationMs.map { DurationEntry.text(digits: DurationEntry.digits(milliseconds: $0)) } ?? ""
                startsAt = event.startsAt
                endsAt = event.endsAt
            } catch {
                errorMessage = "Couldn’t load the event. \(error.localizedDescription)"
            }
        }
        hasLoaded = true
    }

    var distanceM: Int? { isDistance ? Int(amount) : nil }
    var durationMs: Int? { isDistance ? nil : DurationEntry.milliseconds(digits: DurationEntry.digits(from: amount)) }

    /// "2k", "30min" once the piece is set.
    var pieceLabel: String? {
        guard distanceM != nil || durationMs != nil else { return nil }
        return ErgEvent.pieceLabel(distanceM: distanceM, durationMs: durationMs)
    }

    var problem: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give the event a name." }
        if isDistance {
            guard let distanceM, (100...100_000).contains(distanceM) else { return "Set the distance: 100 to 100,000 metres." }
        } else {
            if !amount.isEmpty, durationMs == nil { return "That isn't a time: minutes and seconds go up to 59." }
            guard let durationMs, (30_000...7_200_000).contains(durationMs) else { return "Set the time: 30 seconds to 2 hours." }
        }
        if endsAt <= startsAt { return "The event has to end after it starts." }
        if endsAt.timeIntervalSince(startsAt) > 14 * 86_400 { return "An erg event can last up to two weeks." }
        return nil
    }

    func save() async -> Bool {
        guard problem == nil else { return false }
        isSaving = true
        defer { isSaving = false }
        let draft = ErgEventService.Draft(title: title, distanceM: distanceM, durationMs: durationMs, startsAt: startsAt, endsAt: endsAt)
        do {
            try await ErgEventService.save(id: eventId, draft)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn’t save the event. \(error.localizedDescription)"
            return false
        }
    }

    func delete() async -> Bool {
        guard let eventId else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await ErgEventService.delete(eventId)
            return true
        } catch {
            errorMessage = "Couldn’t delete the event. \(error.localizedDescription)"
            return false
        }
    }

    /// The next whole hour from now.
    private static func nextHour() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        return calendar.date(byAdding: .hour, value: 1, to: hour) ?? now
    }
}
