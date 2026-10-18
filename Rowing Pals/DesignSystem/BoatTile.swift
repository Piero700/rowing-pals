//
//  BoatTile.swift
//  Rowing Pals
//

import SwiftUI

/// One boat as the Boats tab and a water session show it (CoachBoats, CoachSavedBoats; and the
/// rower's read-only water session, decision 79): its name and type, its rigging ("Sculls" for a
/// sculling boat), Sent / Not sent or how often a saved boat has been used, and the boat on its side
/// with first names under the seats, scrolling when it's longer than the card (decision 88) — in the
/// coach's colour for it (decision 87).
struct BoatTile: View {
    enum Footer {
        case sent(Bool)
        case uses(Int)
        case hidden
    }

    let name: String
    let setup: BoatSetup
    let seats: [BoatSeat]
    let names: [UUID: String]
    let footer: Footer
    /// "#RRGGBB" for the hull, or nil.
    var colour: String?
    /// The viewer's own seat, filled in brand blue (the read-only session page).
    var highlightedSeat: Int?

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Boat.cardRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(name)
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                BrandChip(text: setup.type.label)
                Spacer(minLength: Tokens.Spacing.tight)
                footerView
            }
            Text(BoatRules.riggingLine(setup))
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
            SidewaysBoatStrip(setup: setup, names: firstNames, mySeat: highlightedSeat, colour: colour)
                .padding(.top, Tokens.Spacing.tight)
        }
        .padding(.horizontal, Tokens.Spacing.loose)
        .padding(.top, Tokens.Spacing.loose)
        .padding(.bottom, Tokens.Spacing.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.shape.fill(Tokens.Base.ground))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .contentShape(Self.shape)
    }

    private var firstNames: [Int: String] {
        Dictionary(seats.map { ($0.seat, BoatRules.firstName(names[$0.userId])) }, uniquingKeysWith: { first, _ in first })
    }

    @ViewBuilder
    private var footerView: some View {
        switch footer {
        case .sent(let isSent):
            Text(isSent ? "Sent" : "Not sent")
                .textStyle(Typography.chip)
                .foregroundStyle(isSent ? Tokens.Accent.success : Tokens.Ink.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 1)
                .background(Capsule().fill(isSent ? Tokens.Accent.successSoft : Tokens.Surface.raised))
        case .uses(let count):
            Text(count == 1 ? "Used once" : "Used \(count) times")
                .textStyle(Typography.statLabel)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        case .hidden:
            EmptyView()
        }
    }
}
