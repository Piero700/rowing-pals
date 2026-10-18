//
//  CrewBoatViewModel.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// Crew a boat (CoachBoatEdit; decisions 67, 70, 74, 87): its name, type, rigging (custom too) and
/// colour, and who sits where.
/// In a water session the picker offers the rowers who said they can make it (decision 68) — those
/// who can't are shown greyed with their reason — and nobody already in another of its boats; a
/// saved boat offers everyone. Saving a sent boat with changes makes it Not sent again.
@MainActor
@Observable
final class CrewBoatViewModel {
    enum Mode: Equatable {
        case session(UUID, boat: UUID?)
        case saved(UUID?)
    }

    /// One rower the picker offers for the chosen seat.
    struct Candidate: Identifiable, Equatable {
        let member: ClubMember
        let detail: String
        let fits: Bool
        /// A cox offered for a rowing seat: tagged **Cox** in the list (decision 78).
        let isCox: Bool
        /// Why they can't be chosen: "Can’t make it · “Away”", "In W1 four".
        let blockedReason: String?
        /// Their seat in this boat already, if any ("Seat 3").
        let currentSeat: Int?
        var id: UUID { member.id }
    }

    let mode: Mode

    var name = ""
    var type: BoatType = .four {
        didSet {
            let kept = BoatRules.seats(seats.map { BoatSeat(seat: $0.key, userId: $0.value) }, fittingInto: type)
            seats = Dictionary(kept.map { ($0.seat, $0.userId) }, uniquingKeysWith: { first, _ in first })
            if let selectedSeat, !BoatRules.seats(type).contains(selectedSeat) { self.selectedSeat = nil }
            // Custom sides are per seat, so a new boat type starts from the standard rig.
            if rigging == .custom { sides = type.isSculling ? nil : BoatRules.standardSides(type, rigging: .stroke) }
        }
    }
    /// Stroke-rigged, bow-rigged or custom (decision 74). Choosing Custom starts from the rig the
    /// boat had, ready to move single oars across with ⇄.
    var rigging: Rigging = .stroke {
        didSet {
            guard rigging != oldValue else { return }
            if rigging == .custom {
                if sides?.count != type.rowers {
                    sides = BoatRules.standardSides(type, rigging: oldValue == .bow ? .bow : .stroke)
                }
            } else {
                sides = nil
            }
        }
    }
    /// Custom rigging's sides, bow first ("SBBS").
    private(set) var sides: String?

    var setup: BoatSetup { BoatSetup(type: type, rigging: rigging, sides: sides) }
    /// The boat's colour, "#RRGGBB", or nil for none (decision 87): a swatch or any colour.
    var colour: String?
    /// Seat → rower.
    private(set) var seats: [Int: UUID] = [:]
    var selectedSeat: Int?
    var keepSaved = true

    private(set) var members: [ClubMember] = []
    private var rosterInfo: [UUID: (category: RowerCategory, prediction: String?)] = [:]
    private(set) var session: WaterSession?
    private var available: Set<UUID>?
    private var cant: [UUID: String?] = [:]
    private var otherBoats: [UUID: String] = [:]
    private(set) var hasLoaded = false
    private(set) var isSaving = false
    var errorMessage: String?

    private var calendar: Calendar { .current }

    init(mode: Mode) {
        self.mode = mode
    }

    var isNew: Bool {
        switch mode {
        case .session(_, let boat): boat == nil
        case .saved(let id): id == nil
        }
    }
    var isSessionBoat: Bool { if case .session = mode { true } else { false } }

    func member(_ id: UUID?) -> ClubMember? { members.first { $0.id == id } }

    func side(of seat: Int) -> RowingSide? { BoatRules.side(ofSeat: seat, setup: setup) }

    /// ⇄: this seat's oar goes to the other side, and the rigging becomes custom.
    func flip(_ seat: Int) {
        let flipped = BoatRules.flipping(seat, in: setup)
        rigging = .custom
        sides = flipped.sides
    }

    /// "Choose for seat 2 · stroke side".
    var pickerTitle: String? {
        guard let seat = selectedSeat else { return nil }
        let title = BoatRules.seatTitle(seat, type: type)
        let base = "Choose for \(title.prefix(1).lowercased() + title.dropFirst())"
        return side(of: seat).map { "\(base) · \($0.label.lowercased())" } ?? base
    }

    /// "Available Sat 07:00", or nil without answers to check.
    var availabilityCaption: String? {
        guard let session, available != nil else { return nil }
        let weekday = CalendarRules.weekdayShort(session.startsAt, calendar: calendar).capitalized
        return "Available \(weekday) \(CalendarRules.time(session.startsAt, calendar: calendar))"
    }

    /// "4 haven’t answered yet" under the picker, when there are answers to check.
    var unansweredNote: String? {
        guard let available else { return nil }
        let count = members.filter { !available.contains($0.id) && cant[$0.id] == nil && otherBoats[$0.id] == nil }.count
        guard count > 0 else { return nil }
        return "Only rowers who said they can make it are offered. \(count) \(count == 1 ? "hasn’t" : "haven’t") answered yet."
    }

    /// Who the picker offers for the chosen seat: fitting their side first (coxes first for the cox
    /// seat), then by name; those who can't be chosen last.
    var candidates: [Candidate] {
        guard let seat = selectedSeat else { return [] }
        let seatSide = side(of: seat)
        let seatOf = Dictionary(seats.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
        let list = members.compactMap { member -> Candidate? in
            var blocked: String?
            if let other = otherBoats[member.id] {
                blocked = "In \(other)"
            } else if let reason = cant[member.id] {
                blocked = "Can’t make it" + (reason.flatMap { $0 }.map { " · “\($0)”" } ?? "")
            } else if let available, !available.contains(member.id) {
                return nil
            }
            // The cox seat puts coxes first; a rowing seat tags a cox instead (decision 78).
            let fits = BoatRules.suits(member.side, seat: seat, seatSide: seatSide)
            return Candidate(member: member, detail: detail(member), fits: fits, isCox: seat > 0 && member.side == .cox,
                             blockedReason: blocked, currentSeat: seatOf[member.id])
        }
        return list.sorted { a, b in
            if (a.blockedReason == nil) != (b.blockedReason == nil) { return a.blockedReason == nil }
            if a.fits != b.fits { return a.fits }
            return a.member.displayName.localizedCaseInsensitiveCompare(b.member.displayName) == .orderedAscending
        }
    }

    /// "Novice · Stroke side · 2k pred. 7:01".
    private func detail(_ member: ClubMember) -> String {
        var parts: [String] = []
        if let info = rosterInfo[member.id] { parts.append(info.category.rawValue.capitalized) }
        if let side = member.side { parts.append(side == .both ? "Both sides" : side.label) }
        if let prediction = rosterInfo[member.id]?.prediction { parts.append("2k pred. \(prediction)") }
        return parts.joined(separator: " · ")
    }

    var problem: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Give the boat a name." }
        return nil
    }

    func load() async {
        do {
            async let membersTask = CalendarService.members()
            async let rosterTask = try? CoachingService.roster()
            let (members, roster) = try await (membersTask, rosterTask)
            self.members = members
            for rower in roster?.rowers ?? [] {
                rosterInfo[rower.id] = (rower.category, Self.predictedTime(rower.prediction?.predictedTotalTimeSeconds))
            }
            switch mode {
            case .session(let sessionId, let boatId):
                let session = try await BoatService.session(sessionId)
                self.session = session
                let boats = try await BoatService.boats(ofSessions: [sessionId])
                for boat in boats where boat.id != boatId {
                    for seat in boat.seats { otherBoats[seat.userId] = boat.name }
                }
                if let boat = boats.first(where: { $0.id == boatId }) {
                    fill(name: boat.name, setup: boat.setup, seats: boat.seats, colour: boat.colour)
                    keepSaved = boat.savedBoatId != nil
                }
                if let availability = try await BoatService.availability(of: session) {
                    available = availability.available
                    cant = availability.cant
                }
            case .saved(let id):
                if let id {
                    let boat = try await BoatService.savedBoat(id)
                    fill(name: boat.name, setup: boat.setup, seats: boat.seats, colour: boat.colour)
                }
            }
            if selectedSeat == nil { selectedSeat = BoatRules.seats(type).first { seats[$0] == nil } }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the boat. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    private func fill(name: String, setup: BoatSetup, seats: [BoatSeat], colour: String?) {
        self.name = name
        self.colour = BoatPalette.normalised(colour)
        self.type = setup.type
        self.rigging = setup.rigging
        self.sides = setup.sides
        self.seats = Dictionary(seats.map { ($0.seat, $0.userId) }, uniquingKeysWith: { first, _ in first })
    }

    /// Seats `person` in the chosen seat; someone already in this boat swaps places with whoever
    /// was there. Then the next empty seat is chosen.
    func choose(_ person: UUID) {
        guard let seat = selectedSeat else { return }
        let previousSeat = seats.first { $0.value == person }?.key
        let displaced = seats[seat]
        seats[seat] = person
        if let previousSeat, previousSeat != seat {
            seats[previousSeat] = displaced
        }
        selectedSeat = BoatRules.seats(type).first { seats[$0] == nil } ?? seat
    }

    func emptySelectedSeat() {
        guard let seat = selectedSeat else { return }
        seats[seat] = nil
    }

    /// Hold and drag: the two seats swap whoever is in them.
    func swap(_ a: Int, _ b: Int) {
        guard a != b else { return }
        let first = seats[a]
        seats[a] = seats[b]
        seats[b] = first
    }

    func save() async -> Bool {
        guard problem == nil else { return false }
        isSaving = true
        defer { isSaving = false }
        let draft = BoatService.BoatDraft(name: name, setup: setup,
                                          seats: seats.map { BoatSeat(seat: $0.key, userId: $0.value) }.sorted { $0.seat < $1.seat },
                                          colour: BoatPalette.normalised(colour))
        do {
            switch mode {
            case .session(let sessionId, let boatId):
                try await BoatService.saveBoat(id: boatId, session: sessionId, draft, keepSaved: keepSaved)
            case .saved(let id):
                try await BoatService.saveSavedBoat(id: id, draft)
            }
            NotificationCenter.default.post(name: .boatsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t save the boat. \(error.localizedDescription)"
            return false
        }
    }

    func delete() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .session(_, let boatId):
                if let boatId { try await BoatService.deleteBoat(boatId) }
            case .saved(let id):
                if let id { try await BoatService.deleteSavedBoat(id) }
            }
            NotificationCenter.default.post(name: .boatsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t delete the boat. \(error.localizedDescription)"
            return false
        }
    }

    /// "7:01" from the Pace Engine's 2k time in seconds.
    static func predictedTime(_ seconds: Double?) -> String? {
        guard let seconds else { return nil }
        let whole = Int(seconds.rounded())
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
