//
//  RowerWaterSessionView.swift
//  Rowing Pals
//

import SwiftUI

/// A water session from the rower's Calendar, read-only (decision 79): the day and title, Starts–
/// Ends, where to meet, who set it and the plan; then **Your boat** — the shell with their seat in
/// blue and "You’re at bow in M1 four" — and, for a coach, owner, co-owner or admin who sees the whole
/// club's, the **Other boats**. Nothing here can be changed; coaches crew boats in the coach version.
struct RowerWaterSessionView: View {
    @State private var viewModel: RowerWaterSessionViewModel
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(sessionId: UUID) {
        _viewModel = State(initialValue: RowerWaterSessionViewModel(sessionId: sessionId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let session = viewModel.session {
                    summary(session)
                    boatsSection
                } else if viewModel.errorMessage == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Water session") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func summary(_ session: WaterSession) -> some View {
        let calendar = viewModel.calendar
        return VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack(spacing: Tokens.Spacing.loose) {
                DateBlock(date: session.startsAt, calendar: calendar)
                Text(session.title)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                WaterChip(text: "Water")
            }
            detail(.clock, "\(CalendarRules.time(session.startsAt, calendar: calendar))–\(CalendarRules.time(session.endsAt, calendar: calendar))")
            if let meetAt = session.meetAt { detail(.pin, "Meet at \(meetAt)") }
            if let setBy = viewModel.setByName { detail(.people, "Set by \(setBy)") }
            if let plan = session.plan { detail(.list, plan) }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .padding(.top, Tokens.Spacing.tight)
    }

    private func detail(_ symbol: RPIcon, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.gap) {
            RPIconView(icon: symbol, size: Tokens.Icon.detail)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(text)
                .textStyle(Typography.bodySecondary)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    private var boatsSection: some View {
        let mine = viewModel.myBoats
        let others = viewModel.otherBoats
        if mine.isEmpty && others.isEmpty {
            GuidedText("No boats yet.", hint: "Your coach crews the boats and sends them; yours shows here when it’s sent.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.group)
        }
        ForEach(mine) { boat in
            SectionTitle("Your boat")
                .padding(.top, Tokens.Spacing.group)
            if let line = viewModel.seatLine(boat) {
                Text(line)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .padding(.horizontal, 4)
                    .padding(.bottom, Tokens.Spacing.tight)
            }
            tile(boat, highlightedSeat: viewModel.mySeat(in: boat))
                .frame(maxWidth: .infinity)
        }
        if !others.isEmpty {
            SectionTitle(mine.isEmpty ? "Boats" : "Other boats")
                .padding(.top, Tokens.Spacing.group)
            VStack(spacing: Tokens.Spacing.tight) {
                ForEach(others) { boat in
                    tile(boat, highlightedSeat: nil)
                }
            }
        }
    }

    private func tile(_ boat: SessionBoat, highlightedSeat: Int?) -> some View {
        BoatTile(name: boat.name, setup: boat.setup, seats: boat.seats, names: viewModel.names, footer: .hidden,
                 colour: boat.colour, highlightedSeat: highlightedSeat)
    }
}
