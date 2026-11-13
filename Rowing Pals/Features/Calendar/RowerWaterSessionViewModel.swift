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
            // A cox who doesn't row isn't in the members list; their names and the coach's come
            // from one query together.
            let missing = Set(boats.flatMap(\.seats).map(\.userId).filter { names[$0] == nil })
            let looked = (try? await CalendarService.displayNames(of: missing.union(session.createdBy.map { [$0] } ?? []))) ?? [:]
            for id in missing { names[id] = looked[id] }
            if let coach = session.createdBy {
                setByName = looked[coach]
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
