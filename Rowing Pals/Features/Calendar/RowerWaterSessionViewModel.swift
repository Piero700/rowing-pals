//
//  RowerWaterSessionViewModel.swift
//  Rowing Pals
//

import Foundation

/// One water session as a rower sees it, read-only (decision 79): when, where to meet, who set it,
/// the plan, their own boat and seat, and — for a coach, owner, co-owner or admin — the other boats.
@MainActor
@Observable
final class RowerWaterSessionViewModel {
    let sessionId: UUID

    private(set) var session: WaterSession?
    private(set) var boats: [SessionBoat] = []
    private(set) var names: [UUID: String] = [:]
    private(set) var setByName: String?
    private(set) var myId: UUID?
    var errorMessage: String?

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    var calendar: Calendar { .current }

    /// The boats the rower is in (one, as nobody sits in two boats of a session), then the rest.
    var myBoats: [SessionBoat] { boats.filter { boat in boat.seats.contains { $0.userId == myId } } }
    var otherBoats: [SessionBoat] { boats.filter { boat in !boat.seats.contains { $0.userId == myId } } }

    func mySeat(in boat: SessionBoat) -> Int? {
        boat.seats.first { $0.userId == myId }?.seat
    }

    /// "You’re at bow in M1 four".
    func seatLine(_ boat: SessionBoat) -> String? {
        mySeat(in: boat).map { "\(BoatRules.seatPhrase($0, type: boat.boatType)) \(boat.name)" }
    }

    func load() async {
        do {
            myId = try await ViewerContext.shared.current().userId
            async let sessionTask = BoatService.session(sessionId)
            async let boatsTask = BoatService.boats(ofSessions: [sessionId])
            async let membersTask = CalendarService.members()
            let (session, boats, members) = try await (sessionTask, boatsTask, membersTask)
            var names = Dictionary(members.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
            // A cox who doesn't row isn't in the members list; ask for their name on its own.
            for seat in boats.flatMap(\.seats) where names[seat.userId] == nil {
                names[seat.userId] = try? await CalendarService.displayName(of: seat.userId)
            }
            if let coach = session.createdBy {
                setByName = try? await CalendarService.displayName(of: coach)
            }
            self.names = names
            self.boats = boats
            self.session = session
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the session. \(error.localizedDescription)"
        }
    }
}
