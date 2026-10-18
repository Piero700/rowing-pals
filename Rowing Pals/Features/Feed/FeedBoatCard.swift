//
//  FeedBoatCard.swift
//  Rowing Pals
//

import SwiftUI

/// The rower's boat for their next water session, at the top of the Feed (RowerBoat; decision 67):
/// "Your boat · Sat 07:00" and the boat type, "You’re at stroke in M1 four", who set it, the
/// rigging and where to meet, the boat on its side with their seat filled in and the crew's names
/// under their seats — scrolling sideways, opened on their seat (decision 82) — and the plan. A
/// single is just the boat on its side (user, 2026-10-17). Shown on the day until the session ends.
struct FeedBoatCard: View {
    let boat: SessionBoat
    let session: WaterSession
    let names: [UUID: String]
    let coachName: String?
    let mySeat: Int?

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Your boat · \(when)")
                    .textStyle(Typography.kicker)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.brand)
                Spacer(minLength: 0)
                WaterChip(text: boat.boatType.label)
            }
            Text(headline)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.top, 6)
            Text(subtitle)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
                .padding(.bottom, Tokens.Spacing.tight)
            if boat.boatType == .single {
                // A single is just you: the boat on its side, no names, ends or seat list.
                SingleScullDrawing(colour: boat.colour)
                    .padding(.vertical, Tokens.Spacing.tight)
            } else {
                // Bigger boats on their side too, scrolling, opened on your seat (decision 82).
                SidewaysBoatStrip(setup: boat.setup, names: firstNames, mySeat: mySeat, colour: boat.colour)
                    .padding(.top, Tokens.Spacing.tight)
            }
            if let plan = session.plan {
                Text(plan)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, Tokens.Spacing.tight)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(LinearGradient(colors: [Tokens.Accent.brandSoft, Tokens.Surface.card],
                                                       startPoint: .topLeading, endPoint: UnitPoint(x: 0.7, y: 0.7))))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    /// "Sat 07:00".
    private var when: String {
        let calendar = Calendar.current
        return "\(CalendarRules.weekdayShort(session.startsAt, calendar: calendar).capitalized) \(CalendarRules.time(session.startsAt, calendar: calendar))"
    }

    /// "You’re at stroke in M1 four", "You’re coxing M1 four".
    private var headline: String {
        guard let mySeat else { return boat.name }
        return "\(BoatRules.seatPhrase(mySeat, type: boat.boatType)) \(boat.name)"
    }

    /// "From Sarah Lin · stroke-rigged · meet at Boathouse, 06:45".
    private var subtitle: String {
        var parts: [String] = []
        if let coachName { parts.append("From \(coachName)") }
        parts.append(BoatRules.riggingLine(boat.setup).lowercased())
        if let meetAt = session.meetAt { parts.append("meet at \(meetAt)") }
        return parts.joined(separator: " · ")
    }

    private var firstNames: [Int: String] {
        Dictionary(boat.seats.map { ($0.seat, BoatRules.firstName(names[$0.userId])) }, uniquingKeysWith: { first, _ in first })
    }
}
