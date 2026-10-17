//
//  BoatSnapshotTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Renders the Boats tab's boat tiles and the rower's Feed boat card with sample crews to PNGs, to
/// compare with the canvas (CoachBoats, RowerBoat) without a club's data. Writes to
/// $TMPDIR/boats-*.png and checks each render produced an image.
@MainActor
struct BoatSnapshotTests {
    private static let width: CGFloat = 393
    private static let people = ["Marcus Reilly", "Joe Fenwick", "Tom Ashworth", "Piero Ciobanu", "Ella Brook",
                                 "Hannah Lee", "Nina Bergström", "Alice Whitfield", "Kate Simmons", "Priya Shah", "Sam Cole"]
        .map { (UUID(), $0) }
    private static var names: [UUID: String] { Dictionary(uniqueKeysWithValues: people) }

    private static func seats(_ range: Range<Int>, cox: Int? = nil) -> [BoatSeat] {
        var seats = range.enumerated().map { BoatSeat(seat: $0.offset + 1, userId: people[$0.element].0) }
        if let cox { seats.append(BoatSeat(seat: 0, userId: people[cox].0)) }
        return seats
    }

    @Test func boatTilesRender() throws {
        let columns = [GridItem(.adaptive(minimum: Tokens.Boat.cardWidth), spacing: 6, alignment: .top)]
        let view = LazyVGrid(columns: columns, spacing: 6) {
            BoatTile(name: "M1 four", setup: BoatSetup(type: .four, rigging: .stroke), seats: Self.seats(0..<4), names: Self.names, footer: .sent(true))
            BoatTile(name: "W1 four", setup: BoatSetup(type: .coxedFour, rigging: .bow), seats: Self.seats(4..<8, cox: 8), names: Self.names, footer: .sent(true))
            BoatTile(name: "Double", setup: BoatSetup(type: .double, rigging: .stroke), seats: Self.seats(9..<11), names: Self.names, footer: .sent(false))
            BoatTile(name: "Bucket four", setup: BoatSetup(type: .four, rigging: .custom, sides: "SBBS"), seats: Self.seats(0..<4), names: Self.names, footer: .uses(6))
        }
        .padding(Tokens.Spacing.screen)
        try Self.render(view, name: "tiles")
    }

    @Test func feedBoatCardRenders() throws {
        let session = WaterSession(id: UUID(), clubId: UUID(), practiceId: nil, eventId: nil, title: "3 × 2km at rate 28",
                                   startsAt: Date().addingTimeInterval(86_400), meetAt: "the boathouse 06:45",
                                   plan: "3 × 2km at rate 28 · 4′ easy between", createdBy: nil)
        let boat = SessionBoat(id: UUID(), sessionId: session.id, name: "M1 four", boatType: .four, rigging: .stroke,
                               sentAt: Date(), seats: Self.seats(0..<4))
        let view = FeedBoatCard(boat: boat, session: session, names: Self.names, coachName: "Sarah Lin", mySeat: 4)
            .padding(Tokens.Spacing.screen)
        try Self.render(view, name: "feed-card")
    }

    private static func render(_ content: some View, name: String) throws {
        for scheme in [ColorScheme.dark, .light] {
            let view = content
                .frame(width: width)
                .background(Tokens.Base.ground)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            let data = try #require(image.pngData())
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("boats-\(name)-\(scheme == .dark ? "dark" : "light").png")
            try data.write(to: url)
            print("Boats snapshot: \(url.path)")
            #expect(image.size.width > 0)
        }
    }
}
