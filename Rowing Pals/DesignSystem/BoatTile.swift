//
//  BoatTile.swift
//  Rowing Pals
//

import SwiftUI

/// One boat as the Boats tab and a water session show it (CoachBoats, CoachSavedBoats; and the
/// rower's read-only water session, decision 79): its name and type, its rigging ("Sculls" for a
/// sculling boat), the small shell drawing with first names, and a line under it — Sent / Not sent,
/// how often a saved boat has been used, or nothing.
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
    var orientation: BoatOrientation = .sternAtTop
    /// The viewer's own seat, filled in brand blue (the read-only session page).
    var highlightedSeat: Int?

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Boat.cardRadius, style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(name)
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                BrandChip(text: setup.type.label)
            }
            .padding(.horizontal, Tokens.Spacing.tight)
            Text(BoatRules.riggingLine(setup))
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
                .padding(.bottom, 6)
            BoatEndLabel(text: orientation == .sternAtTop ? "Stern" : "Bow")
            BoatDrawing(setup: setup, orientation: orientation, names: firstNames, highlightedSeat: highlightedSeat)
            BoatEndLabel(text: orientation == .sternAtTop ? "Bow" : "Stern")
            if case .hidden = footer {} else {
                footerView
                    .padding(.top, 6)
            }
        }
        .padding(.top, Tokens.Spacing.gap)
        .padding(.bottom, Tokens.Spacing.tight)
        .frame(width: Tokens.Boat.cardWidth)
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
