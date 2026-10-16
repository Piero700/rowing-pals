//
//  NextBoatModel.swift
//  Rowing Pals
//

import Foundation

/// The Feed's boat card (RowerBoat; decision 67): the rower's next sent boat, from when it's sent
/// until the session starts, with its crew and who set it.
@MainActor
@Observable
final class NextBoatModel {
    private(set) var boat: SessionBoat?
    private(set) var session: WaterSession?
    private(set) var names: [UUID: String] = [:]
    private(set) var coachName: String?
    private(set) var mySeat: Int?

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            guard viewer.clubId != nil, let next = try await BoatService.myNextBoat() else {
                boat = nil
                return
            }
            let members = try await CalendarService.members()
            var names = Dictionary(members.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
            // A cox who doesn't row isn't in the members list; ask for their name on its own.
            for seat in next.boat.seats where names[seat.userId] == nil {
                names[seat.userId] = try? await CalendarService.displayName(of: seat.userId)
            }
            self.names = names
            coachName = try? await next.session.createdBy.asyncMap { try await CalendarService.displayName(of: $0) }
            mySeat = next.boat.seats.first { $0.userId == viewer.userId }?.seat
            session = next.session
            boat = next.boat
        } catch {
            // Before the boats migration there's nothing to show; the Feed carries on.
            boat = nil
        }
    }
}

private extension Optional {
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        guard let value = self else { return nil }
        return try await transform(value)
    }
}
