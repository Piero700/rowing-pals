//
//  WaterSessionView.swift
//  Rowing Pals
//

import SwiftUI

/// A water session, new or to edit (CoachWaterSessionNew; decision 67): Title, Date and Time, Meet
/// at, The plan; its Boats, each opening the crewing screen and swiped left to delete (user,
/// 2026-11-03); Add boat (saved or new); and Send, which tells each rower their boat and seat.
/// Editing adds Delete session.
struct WaterSessionView: View {
    @State private var viewModel: WaterSessionViewModel
    @State private var isAddingBoat = false
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(sessionId: UUID?, seed: WaterSessionSeed = WaterSessionSeed()) {
        _viewModel = State(initialValue: WaterSessionViewModel(sessionId: sessionId, seed: seed))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.hasLoaded {
                    form
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Water session") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .onAppear { Task { await viewModel.reloadBoats() } }
        .onDisappear { Task { await viewModel.saveOnLeaving() } }
        .sheet(isPresented: $isAddingBoat) {
            AddBoatSheet(viewModel: viewModel) { saved in
                isAddingBoat = false
                Task { await viewModel.add(saved) }
            } onNew: {
                isAddingBoat = false
                Task {
                    if let id = await viewModel.ensureSaved() { navigate(.sessionBoat(session: id, boat: nil)) }
                }
            }
        }
        .alert("Delete this water session?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its boats go too, and come off the Feed of everyone in them.")
        }
    }

    @ViewBuilder
    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
            GroupedSection {
                GroupedTextRow(label: "Title", placeholder: "3 × 2km at rate 28", text: $viewModel.title)
                GroupedDivider()
                GroupedTextRow(label: "Meet at", placeholder: "Boathouse, 06:45", text: $viewModel.meetAt)
            }
            // Starts and Ends, as a practice's (decisions 73, 79): the end follows the start.
            GroupedSection {
                GroupedRow(label: "Date") {
                    DatePicker("Date", selection: $viewModel.day, displayedComponents: .date)
                        .labelsHidden()
                }
                GroupedDivider()
                GroupedRow(label: "Starts") {
                    DatePicker("Starts", selection: $viewModel.time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                GroupedDivider()
                GroupedRow(label: "Ends") {
                    DatePicker("Ends", selection: $viewModel.endTime, in: viewModel.endRange, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            GroupedSection(header: "The plan") {
                GroupedNotesRow(placeholder: "Pieces, rates, where to turn…", text: $viewModel.plan)
            }
        }

        // Save the details now and see that they're saved (user, 2026-10-18); leaving still saves.
        Button {
            Task { await viewModel.save() }
        } label: {
            if viewModel.hasUnsavedChanges {
                Text(viewModel.isNew ? "Save session" : "Save changes")
            } else {
                Label("Saved", icon: .check, size: Tokens.Icon.small)
            }
        }
        .buttonStyle(.rpGlass)
        .disabled(!viewModel.hasUnsavedChanges || viewModel.isWorking)
        .padding(.top, Tokens.Spacing.loose)

        HStack(alignment: .firstTextBaseline) {
            FormSectionTitle("Boats")
            Spacer(minLength: 0)
            Text(viewModel.summary)
                .textStyle(Typography.statLabel)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, Tokens.Spacing.group)
        }
        if !viewModel.boats.isEmpty {
            VStack(spacing: Tokens.Spacing.tight) {
                ForEach(viewModel.boats) { boat in
                    Button {
                        if let id = viewModel.sessionId { navigate(.sessionBoat(session: id, boat: boat.id)) }
                    } label: {
                        BoatTile(name: boat.name, setup: boat.setup, seats: boat.seats,
                                 names: viewModel.names, footer: .sent(boat.isSent), colour: boat.colour)
                    }
                    .buttonStyle(IconPressStyle())
                    .swipeToDelete(cornerRadius: Tokens.Boat.cardRadius) { await viewModel.deleteBoat(boat.id) }
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
            if viewModel.hasTitle { isAddingBoat = true } else { viewModel.errorMessage = "Give the session a title first." }
        } label: {
            Label("Add boat", icon: .plus)
        }
        .buttonStyle(.rpGlass)
        .disabled(viewModel.isWorking)
        .padding(.top, Tokens.Spacing.loose)

        VStack(alignment: .leading, spacing: 2) {
            Text("Each rower is told their boat and seat")
                .textStyle(Typography.rowTitle)
                .foregroundStyle(Tokens.Ink.primary)
            Text("\(viewModel.exampleAlert). It’s on their Feed on the day until the session ends, and in their Calendar.")
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
        .padding(.top, Tokens.Spacing.group)

        if let error = viewModel.errorMessage {
            Text(error)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.loose)
        }

        Button {
            Task { if await viewModel.send() { dismiss() } }
        } label: {
            if viewModel.isWorking {
                ProgressView().tint(Tokens.Ink.onBrand)
            } else {
                Text(sendTitle)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(viewModel.isWorking || viewModel.unsentRowers == 0)
        .padding(.top, Tokens.Spacing.loose)

        if !viewModel.isNew {
            GroupedSection {
                GroupedButtonRow(title: "Delete session", isDestructive: true, isCentred: true) { isConfirmingDelete = true }
            }
            .disabled(viewModel.isWorking)
            .padding(.top, Tokens.Spacing.group)
        }
    }

    private var sendTitle: String {
        let count = viewModel.unsentRowers
        if count == 0 { return viewModel.boats.contains(where: \.isSent) ? "All boats sent" : "Send" }
        return "Send to \(count) rower\(count == 1 ? "" : "s")"
    }
}
