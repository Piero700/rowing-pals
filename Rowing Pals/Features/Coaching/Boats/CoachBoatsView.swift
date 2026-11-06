//
//  CoachBoatsView.swift
//  Rowing Pals
//

import SwiftUI

/// The coach version's **Boats** tab (CoachBoats, CoachSavedBoats; decisions 67, 70): Sessions —
/// today's and upcoming water sessions, each with its boats on their side (decision 88) and whether
/// they've been sent, then who's going to the next one but isn't in a boat yet — and Saved boats, the crews
/// the club puts out again and again. Swipe a boat left to delete it (user, 2026-11-03). A water
/// session is new from + → Water session.
struct CoachBoatsView: View {
    var reselects = 0
    var refreshes = 0

    @State private var viewModel = CoachBoatsViewModel()
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PillSegmentedControl(options: ["Sessions", "Saved boats"], selection: Binding(
                    get: { viewModel.tab.rawValue },
                    set: { viewModel.tab = CoachBoatsViewModel.Tab(rawValue: $0) ?? .sessions }
                ))
                .padding(.bottom, Tokens.Spacing.loose)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.bottom, Tokens.Spacing.loose)
                }

                if !viewModel.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if viewModel.tab == .sessions {
                    sessionsList
                } else {
                    savedList
                }
                Color.clear.frame(height: Tokens.Spacing.tabScrollBottom)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .scrollsToTopOnReselect(reselects) { await viewModel.load() }
        .safeAreaInset(edge: .top, spacing: 0) { CoachTabHeader(title: "Boats") }
        .background(Tokens.Base.ground)
        .tracksFloatingBar()
        .ignoresSafeArea(edges: .bottom)
        .task { await viewModel.load() }
        .onChange(of: refreshes) { Task { await viewModel.load() } }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .calendarChanged)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .boatsChanged)) { _ in
            Task { await viewModel.load() }
        }
    }

    // MARK: - Sessions

    @ViewBuilder
    private var sessionsList: some View {
        if viewModel.sessions.isEmpty {
            GuidedText("No water sessions coming up.", hint: "Tap + and choose Water session to plan one and crew its boats.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        }
        if !viewModel.today.isEmpty {
            sectionHeader("Today", trailing: viewModel.summary(of: viewModel.today), isFirst: true)
            ForEach(viewModel.today) { session in
                sessionCard(session)
            }
        }
        if !viewModel.upcoming.isEmpty {
            sectionHeader("Upcoming", trailing: nil, isFirst: viewModel.today.isEmpty)
            ForEach(viewModel.upcoming) { session in
                sessionCard(session)
            }
        }
        if let unseated = viewModel.unseated {
            sectionHeader("Not in a boat yet", trailing: CalendarRules.dayLabel(unseated.session.startsAt, calendar: .current), isFirst: false)
            VStack(alignment: .leading, spacing: 6) {
                WrapLayout(spacing: 6) {
                    ForEach(unseated.people) { person in
                        Text(person.displayName)
                            .textStyle(Typography.chip)
                            .foregroundStyle(Tokens.Ink.primary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .frame(minHeight: Tokens.Size.chip)
                            .background(Capsule().fill(Tokens.Surface.raised))
                    }
                }
                Text("Going on \(weekday(unseated.session.startsAt)) but not seated in a boat.")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        }
    }

    private func sessionCard(_ session: WaterSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                navigate(.waterSession(session.id))
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: Tokens.Spacing.tight) {
                        Text(viewModel.when(session))
                            .textStyle(Typography.meta)
                            .fontWeight(.semibold)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Accent.brand)
                        Spacer(minLength: 0)
                        WaterChip(text: "Water")
                    }
                    Text(session.title)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 6)
                    if let meetAt = session.meetAt {
                        Text("Meet at \(meetAt)")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.top, 2)
                    }
                    if let plan = session.plan {
                        Text(plan)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())

            let boats = viewModel.boats[session.id] ?? []
            if boats.isEmpty {
                Text("No boats yet. Open the session to add them.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.loose)
            } else {
                VStack(spacing: Tokens.Spacing.tight) {
                    ForEach(boats) { boat in
                        Button {
                            navigate(.sessionBoat(session: session.id, boat: boat.id))
                        } label: {
                            BoatTile(name: boat.name, setup: boat.setup, seats: boat.seats,
                                     names: viewModel.names, footer: .sent(boat.isSent), colour: boat.colour)
                        }
                        .buttonStyle(IconPressStyle())
                        .swipeToDelete(cornerRadius: Tokens.Boat.cardRadius) { await viewModel.deleteBoat(boat) }
                    }
                }
                // A swiped boat slides under the card's edge, not out over it.
                .clipped()
                .padding(.top, Tokens.Spacing.loose)
            }
        }
        .padding(.vertical, Tokens.Spacing.card)
        .padding(.horizontal, Tokens.Spacing.gap)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        .padding(.bottom, Tokens.Spacing.tight)
    }

    // MARK: - Saved boats

    @ViewBuilder
    private var savedList: some View {
        Text("Crews you put out again and again. Add one to a session in a tap, then swap anyone who can’t make it.")
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, Tokens.Spacing.loose)
            .guidance()
        if viewModel.savedBoats.isEmpty {
            GuidedText("No saved boats yet.", hint: "Save one here, or turn on Keep in Saved boats when you crew a boat.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        } else {
            VStack(spacing: Tokens.Spacing.tight) {
                ForEach(viewModel.savedBoats) { boat in
                    Button {
                        navigate(.savedBoat(boat.id))
                    } label: {
                        BoatTile(name: boat.name, setup: boat.setup, seats: boat.seats,
                                 names: viewModel.names, footer: .uses(boat.uses), colour: boat.colour)
                    }
                    .buttonStyle(IconPressStyle())
                    .swipeToDelete(cornerRadius: Tokens.Boat.cardRadius) { await viewModel.deleteSavedBoat(boat.id) }
                }
            }
            // A swiped boat slides under the card's edge, not out over it.
            .clipped()
            .padding(.vertical, Tokens.Spacing.loose)
            .padding(.horizontal, Tokens.Spacing.gap)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        }
        Button {
            navigate(.savedBoat(nil))
        } label: {
            Label("New saved boat", icon: .plus)
        }
        .buttonStyle(.rpGlass)
        .padding(.top, Tokens.Spacing.loose)
    }

    // MARK: - Pieces

    private func sectionHeader(_ title: String, trailing: String?, isFirst: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Tokens.Spacing.tight)
            if let trailing {
                Text(trailing)
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, isFirst ? 0 : Tokens.Spacing.group)
        .padding(.bottom, Tokens.Spacing.tight)
    }

    /// "Saturday".
    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
