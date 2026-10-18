//
//  FeedBoatsModel.swift
//  Rowing Pals
//

import Foundation

/// The Feed's boat cards (RowerBoat; decisions 67, 79): the rower's sent boats for today, each until
/// its session ends; once today's are over, tomorrow's. Each with its crew and who set it.
@MainActor
@Observable
final class FeedBoatsModel {
    struct Item: Identifiable {
        let boat: SessionBoat
        let session: WaterSession
        let mySeat: Int?
        let coachName: String?
        var id: UUID { boat.id }
    }

    private(set) var items: [Item] = []
    private(set) var names: [UUID: String] = [:]

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            guard viewer.clubId != nil else {
                items = []
                return
            }
            let mine = BoatRules.feedBoats(try await BoatService.myBoats(), session: \.session,
                                           now: Date(), calendar: .current)
            guard !mine.isEmpty else {
                items = []
                return
            }
            let members = try await CalendarService.members()
            var names = Dictionary(members.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
            // A cox who doesn't row isn't in the members list; ask for their name on its own.
            for seat in mine.flatMap(\.boat.seats) where names[seat.userId] == nil {
                names[seat.userId] = try? await CalendarService.displayName(of: seat.userId)
            }
            var coaches: [UUID: String] = [:]
            for id in Set(mine.compactMap(\.session.createdBy)) {
                coaches[id] = try? await CalendarService.displayName(of: id)
            }
            self.names = names
            items = mine.map { pair in
                Item(boat: pair.boat, session: pair.session,
                     mySeat: pair.boat.seats.first { $0.userId == viewer.userId }?.seat,
                     coachName: pair.session.createdBy.flatMap { coaches[$0] })
            }
        } catch {
            // A failed or cancelled load keeps the cards already shown; they only go when the
            // database says there are none (user, 2026-10-18).
        }
    }
}
