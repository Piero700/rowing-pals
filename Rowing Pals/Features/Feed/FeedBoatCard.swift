//
//  FeedBoatCard.swift
//  Rowing Pals
//

import SwiftUI

/// The rower's boat for their next water session, at the top of the Feed (RowerBoat; decision 67):
/// "Your boat · Sat 07:00" and the boat type, "You’re at stroke in M1 four", who set it, the
/// rigging and where to meet, the boat drawn upright with their seat filled in, the crew seat by
/// seat, and the plan. It stays until the session starts.
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
            HStack(alignment: .top, spacing: Tokens.Spacing.tight) {
                BoatDrawing(type: boat.boatType, rigging: boat.rigging, names: firstNames, highlightedSeat: mySeat)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(BoatRules.seats(boat.boatType), id: \.self) { seat in
                        seatRow(seat)
                    }
                }
                .padding(.top, Tokens.Boat.small.firstSeat - Tokens.Boat.seatRow / 2)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        parts.append(boat.boatType.isSculling ? "sculls" : boat.rigging.label.lowercased())
        if let meetAt = session.meetAt { parts.append("meet at \(meetAt)") }
        return parts.joined(separator: " · ")
    }

    private var firstNames: [Int: String] {
        Dictionary(boat.seats.map { ($0.seat, BoatRules.firstName(names[$0.userId])) }, uniquingKeysWith: { first, _ in first })
    }

    private func seatRow(_ seat: Int) -> some View {
        let person = boat.seats.first { $0.seat == seat }.flatMap { names[$0.userId] }
        let isMine = seat == mySeat
        return HStack(spacing: Tokens.Spacing.tight) {
            Text(BoatRules.seatName(seat, type: boat.boatType))
                .textStyle(Typography.chip)
                .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.secondary)
                .frame(width: Tokens.Boat.seatColumn, alignment: .leading)
            Text(person ?? "—")
                .textStyle(Typography.meta)
                .fontWeight(isMine ? .semibold : .regular)
                .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.primary)
                .lineLimit(1)
        }
        .frame(minHeight: Tokens.Boat.seatRow)
    }
}
