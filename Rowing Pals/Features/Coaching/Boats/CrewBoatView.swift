//
//  CrewBoatView.swift
//  Rowing Pals
//

import SwiftUI
import UniformTypeIdentifiers

/// Crew a boat (CoachBoatEdit; decisions 67, 70): Boat name, Boat type (1x 2x 2− 4− 4+ 4x 8+),
/// Rigging (stroke- or bow-rigged; none for sculls), then the crew drawn upright — bow at the top,
/// each rower's name beside their seat on their oar's side, "Usually stroke side" when they're on
/// their other side. Tap a seat, then a rower; hold and drag a name onto another seat to swap.
/// In a session: Keep in Saved boats, Save boat, Delete boat. For a saved boat: Save, Delete.
struct CrewBoatView: View {
    @State private var viewModel: CrewBoatViewModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let buttonShape = RoundedRectangle(cornerRadius: Tokens.Boat.seatButtonRadius, style: .continuous)

    init(mode: CrewBoatViewModel.Mode) {
        _viewModel = State(initialValue: CrewBoatViewModel(mode: mode))
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
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: viewModel.isSessionBoat ? "Boat" : "Saved boat") { dismiss() }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .alert("Delete \(viewModel.name.isEmpty ? "this boat" : viewModel.name)?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.isSessionBoat
                 ? "It comes out of this session, and off the Feed of everyone in it."
                 : "It comes out of Saved boats. Sessions it was added to keep their boats.")
        }
    }

    @ViewBuilder
    private var form: some View {
        FormLabel("Boat name").padding(.top, Tokens.Spacing.card)
        TextField("M1 four", text: $viewModel.name)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()

        FormLabel("Boat type").padding(.top, Tokens.Spacing.card)
        WrapLayout(spacing: 6) {
            ForEach(BoatType.allCases, id: \.self) { type in
                Button(type.label) { viewModel.type = type }
                    .buttonStyle(.rpPill(isOn: viewModel.type == type))
                    .monospacedDigit()
            }
        }

        if !viewModel.type.isSculling {
            FormLabel("Rigging").padding(.top, Tokens.Spacing.card)
            PillSegmentedControl(options: Rigging.allCases.map(\.label), selection: Binding(
                get: { Rigging.allCases.firstIndex(of: viewModel.rigging) ?? 0 },
                set: { viewModel.rigging = Rigging.allCases[$0] }
            ))
            FormFootnote("Stroke-rigged: the stroke’s oar is on stroke side, then the seats alternate. Bow-rigged is the other way round.")
        }

        HStack(alignment: .firstTextBaseline) {
            FormSectionTitle("Crew")
            Spacer(minLength: 0)
            Text("Bow at the top")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, Tokens.Spacing.group)
        }
        crewCard
        FormFootnote("Tap a seat, then a rower. Hold and drag a rower to swap seats. Rowers set their side in their profile.")

        picker

        if viewModel.isSessionBoat {
            ToggleCard(title: "Keep in Saved boats", detail: "Add this crew to later sessions in a tap.", isOn: $viewModel.keepSaved)
                .padding(.top, Tokens.Spacing.group)
        }

        if let error = viewModel.errorMessage {
            Text(error)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.loose)
        }

        Button {
            Task { if await viewModel.save() { dismiss() } }
        } label: {
            if viewModel.isSaving {
                ProgressView().tint(Tokens.Ink.onBrand)
            } else {
                Text("Save boat")
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(viewModel.isSaving || viewModel.problem != nil)
        .padding(.top, Tokens.Spacing.card)

        if !viewModel.isNew {
            Button("Delete boat") { isConfirmingDelete = true }
                .buttonStyle(.rpDestructive)
                .disabled(viewModel.isSaving)
                .padding(.top, Tokens.Spacing.tight)
        }
    }

    // MARK: - The crew drawing

    private var crewCard: some View {
        let metrics = Tokens.Boat.large
        let layout = BoatDrawing.Layout(type: viewModel.type, metrics: metrics)
        let empty = Set(BoatRules.seats(viewModel.type).filter { viewModel.seats[$0] == nil })
        return VStack(spacing: 0) {
            if !viewModel.type.isSculling {
                HStack {
                    Text("Stroke side")
                    Spacer(minLength: 0)
                    Text("Bow side")
                }
                .textStyle(Typography.tag)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, Tokens.Spacing.card)
                .padding(.bottom, Tokens.Spacing.tight)
            }
            ZStack(alignment: .topLeading) {
                BoatDrawing(type: viewModel.type, rigging: viewModel.rigging, metrics: metrics,
                            selectedSeat: viewModel.selectedSeat, emptySeats: empty)
                ForEach(BoatRules.seats(viewModel.type), id: \.self) { seat in
                    seatButton(seat)
                        .frame(width: metrics.nameWidth)
                        .position(x: seatButtonX(seat, metrics: metrics), y: layout.seatY(seat))
                }
            }
            .frame(width: metrics.width, height: layout.height)
            Text("Stern")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, Tokens.Spacing.gap)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Spacing.loose)
        .padding(.bottom, Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func seatButtonX(_ seat: Int, metrics: Tokens.Boat.Metrics) -> CGFloat {
        let right = seat == 0 || BoatRules.isOnRight(seat: seat, type: viewModel.type, rigging: viewModel.rigging)
        return right ? metrics.width - 4 - metrics.nameWidth / 2 : 4 + metrics.nameWidth / 2
    }

    @ViewBuilder
    private func seatButton(_ seat: Int) -> some View {
        let person = viewModel.member(viewModel.seats[seat])
        let isSelected = viewModel.selectedSeat == seat
        let right = seat == 0 || BoatRules.isOnRight(seat: seat, type: viewModel.type, rigging: viewModel.rigging)
        let seatSide = viewModel.side(of: seat)
        let button = Button {
            viewModel.selectedSeat = seat
        } label: {
            Group {
                if let person {
                    VStack(alignment: right ? .leading : .trailing, spacing: 2) {
                        Text(person.displayName)
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                        if let note = BoatRules.offSideNote(person.side, seatSide: seatSide) {
                            Text(note)
                                .textStyle(Typography.statLabel)
                                .fontWeight(.semibold)
                                .foregroundStyle(Tokens.Ink.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 6)
                                .background(Capsule().fill(Tokens.Surface.raised))
                        } else {
                            Text(seat == 0 ? "Cox" : (person.side.map { $0 == .both ? "Both sides" : $0.label } ?? BoatRules.seatName(seat, type: viewModel.type)))
                                .textStyle(Typography.statLabel)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: right ? .leading : .trailing)
                    .padding(.horizontal, Tokens.Spacing.gap)
                    .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        Text(BoatRules.seatTitle(seat, type: viewModel.type))
                            .textStyle(Typography.meta)
                            .fontWeight(.semibold)
                        if let seatSide {
                            Text(seatSide.label)
                                .textStyle(Typography.statLabel)
                        }
                    }
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(minHeight: Tokens.Boat.seatButtonHeight)
            .background(Self.buttonShape.fill(person == nil ? Color.clear : Tokens.Surface.card))
            .overlay {
                if person == nil || isSelected {
                    Self.buttonShape.strokeBorder(Tokens.Accent.brand,
                                                  style: StrokeStyle(lineWidth: isSelected ? Tokens.Boat.selectedLineWidth : 1.5,
                                                                     dash: person == nil ? Tokens.Boat.dash : []))
                } else {
                    Self.buttonShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1)
                }
            }
            .contentShape(Self.buttonShape)
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(person.map { "\(BoatRules.seatName(seat, type: viewModel.type)): \($0.displayName)" }
                            ?? "\(BoatRules.seatTitle(seat, type: viewModel.type)), empty")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dropDestination(for: String.self) { items, _ in
            guard let from = items.first.flatMap(Int.init) else { return false }
            viewModel.swap(from, seat)
            return true
        }
        if person != nil {
            button.draggable(String(seat))
        } else {
            button
        }
    }

    // MARK: - Choosing a rower

    @ViewBuilder
    private var picker: some View {
        if let title = viewModel.pickerTitle {
            HStack(alignment: .firstTextBaseline) {
                FormSectionTitle(title)
                Spacer(minLength: 0)
                if let caption = viewModel.availabilityCaption {
                    Text(caption)
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, Tokens.Spacing.group)
                }
            }
            let candidates = viewModel.candidates
            VStack(spacing: 0) {
                if viewModel.seats[viewModel.selectedSeat ?? -1] != nil {
                    Button {
                        viewModel.emptySelectedSeat()
                    } label: {
                        Text("Empty this seat")
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Accent.brand)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Tokens.Spacing.card)
                            .frame(minHeight: Tokens.Size.rowCompact)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    if !candidates.isEmpty { Rectangle().fill(Tokens.Surface.line).frame(height: 1) }
                }
                if candidates.isEmpty {
                    Text("Nobody to offer yet: rowers appear here once they say they can make it.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Tokens.Spacing.card)
                }
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                    if index > 0 { Rectangle().fill(Tokens.Surface.line).frame(height: 1) }
                    candidateRow(candidate)
                }
            }
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .clipShape(Self.cardShape)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            if let note = viewModel.unansweredNote {
                FormFootnote(note)
            }
        }
    }

    private func candidateRow(_ candidate: CrewBoatViewModel.Candidate) -> some View {
        Button {
            viewModel.choose(candidate.member.id)
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                AvatarPlaceholder(diameter: Tokens.Size.rowIcon, name: candidate.member.displayName, userId: candidate.member.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.member.displayName)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(candidate.blockedReason ?? candidate.detail)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let current = candidate.currentSeat {
                    Text(BoatRules.seatTitle(current, type: viewModel.type))
                        .textStyle(Typography.chip)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Tokens.Surface.raised))
                } else if candidate.fits && candidate.blockedReason == nil {
                    BrandChip(text: "Fits")
                }
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.tight)
            .frame(minHeight: Tokens.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .disabled(candidate.blockedReason != nil)
        .opacity(candidate.blockedReason == nil ? 1 : 0.55)
    }
}
