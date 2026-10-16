//
//  BoatTile.swift
//  Rowing Pals
//

import SwiftUI

/// One boat as the Boats tab and a water session show it (CoachBoats, CoachSavedBoats): its name
/// and type, its rigging ("Sculls" for a sculling boat), the small upright drawing with first
/// names, and a line under it — Sent / Not sent, or how often a saved boat has been used.
struct BoatTile: View {
    enum Footer {
        case sent(Bool)
        case uses(Int)
    }

    let name: String
    let type: BoatType
    let rigging: Rigging
    let seats: [BoatSeat]
    let names: [UUID: String]
    let footer: Footer

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Boat.cardRadius, style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(name)
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                    .lineLimit(1)
                BrandChip(text: type.label)
            }
            .padding(.horizontal, Tokens.Spacing.tight)
            Text(type.isSculling ? "Sculls" : rigging.label)
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
                .padding(.bottom, 6)
            BoatDrawing(type: type, rigging: rigging, names: firstNames)
            footerView
                .padding(.top, 6)
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
        }
    }
}
