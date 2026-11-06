//
//  CrewBoatView.swift
//  Rowing Pals
//

import SwiftUI
import UniformTypeIdentifiers

/// Crew a boat (CoachBoatEdit; decisions 67, 70, 87, 88): Boat name, Boat type (1x 2x 2− 4− 4+ 4x 4x+
/// 8+), Rigging (stroke-rigged, bow-rigged or custom with ⇄ on each oar; none for sculls), Colour (none,
/// a swatch or any colour), then the crew: the boat on its side as the rower's Feed draws it, stern on
/// the left, scrolling when it's longer than the card, with a button under each seat — the rower's
/// name, "Usually stroke side" when they're on their other side, or the empty seat dashed. Tap a seat
/// (or its button), then a rower; hold and drag a name onto another seat to swap.
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
        GroupedSection {
            GroupedTextRow(label: "Boat name", placeholder: "M1 four", text: $viewModel.name)
        }
        .padding(.top, Tokens.Spacing.tight)

        FormLabel("Boat type").padding(.top, Tokens.Spacing.card)
        // One row that scrolls sideways (user, 2026-10-18), so the eight types never stack.
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(BoatType.allCases, id: \.self) { type in
                    Button(type.label) { viewModel.type = type }
                        .buttonStyle(.rpPill(isOn: viewModel.type == type))
                        .monospacedDigit()
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()

        if !viewModel.type.isSculling {
            FormLabel("Rigging").padding(.top, Tokens.Spacing.card)
            PillSegmentedControl(options: Rigging.allCases.map(\.label), selection: Binding(
                get: { Rigging.allCases.firstIndex(of: viewModel.rigging) ?? 0 },
                set: { viewModel.rigging = Rigging.allCases[$0] }
            ))
            FormFootnote(viewModel.rigging == .custom
                ? "Custom: tap ⇄ beside an oar to put it on the other side — for a bucket rig or any staggered setup."
                : "Stroke-rigged: the stroke’s oar is on stroke side, then the seats alternate. Bow-rigged is the other way round.")
                .guidance()
        }

        FormLabel("Colour").padding(.top, Tokens.Spacing.card)
        colourRow
        FormFootnote("Colour a boat to pick it out at a glance. Its crew see it on their Feed too.")
            .guidance()

        FormSectionTitle("Crew")
        crewCard
        FormFootnote("Tap a seat, then a rower. Hold and drag a rower to swap seats. Rowers set their side in their profile.")
            .guidance()

        picker

        if viewModel.isSessionBoat {
            GroupedSection {
                GroupedToggleRow(label: "Keep in Saved boats", hint: "Add this crew to later sessions in a tap.", isOn: $viewModel.keepSaved)
            }
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

    // MARK: - Colour

    /// None, the swatches, then Apple's colour picker for any other colour (decision 87).
    private var colourRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Tokens.Spacing.tight) {
                Button {
                    viewModel.colour = nil
                } label: {
                    // A slashed circle: no colour.
                    Circle()
                        .strokeBorder(Tokens.Ink.secondary, lineWidth: 1.5)
                        .overlay {
                            Rectangle()
                                .fill(Tokens.Ink.secondary)
                                .frame(width: 1.5, height: Tokens.Boat.swatch)
                                .rotationEffect(.degrees(45))
                        }
                        .clipShape(Circle())
                        .frame(width: Tokens.Boat.swatch, height: Tokens.Boat.swatch)
                        .padding(Tokens.Boat.swatchRing * 1.6)
                        .overlay { if viewModel.colour == nil { ring } }
                        .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                .accessibilityLabel("No colour")
                .accessibilityAddTraits(viewModel.colour == nil ? .isSelected : [])
                ForEach(BoatPalette.swatches) { swatch in
                    let isOn = viewModel.colour == swatch.hex
                    Button {
                        viewModel.colour = swatch.hex
                    } label: {
                        Circle()
                            .fill(BoatPalette.color(swatch.hex) ?? Tokens.Surface.raised)
                            .overlay { Circle().strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
                            .frame(width: Tokens.Boat.swatch, height: Tokens.Boat.swatch)
                            .padding(Tokens.Boat.swatchRing * 1.6)
                            .overlay { if isOn { ring } }
                            .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.minTap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
                // Any other colour: Apple's picker, showing the boat's colour when it isn't a swatch.
                let isCustom = viewModel.colour != nil && !BoatPalette.swatches.contains { $0.hex == viewModel.colour }
                ColorPicker("Any colour", selection: Binding(
                    get: { BoatPalette.color(viewModel.colour) ?? Tokens.Ink.primary },
                    set: { viewModel.colour = BoatPalette.hex($0) }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: Tokens.Boat.swatch, height: Tokens.Boat.swatch)
                .padding(Tokens.Boat.swatchRing * 1.6)
                .overlay { if isCustom { ring } }
                .frame(minWidth: Tokens.Size.minTap, minHeight: Tokens.Size.minTap)
                .accessibilityLabel(isCustom ? "Custom colour, chosen" : "Any colour")
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    /// The ring round the chosen colour.
    private var ring: some View {
        Circle().strokeBorder(Tokens.Accent.brand, lineWidth: Tokens.Boat.swatchRing)
    }

    // MARK: - The crew drawing

    /// The boat on its side (decision 88): a tap target on every seat, a name button under it, and ⇄
    /// beside each oar for custom rigging. Longer boats scroll, as on the rower's Feed.
    private var crewCard: some View {
        let empty = Set(BoatRules.seats(viewModel.type).filter { viewModel.seats[$0] == nil })
        let isSweep = !viewModel.type.isSculling
        return VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            SidewaysBoatStrip(setup: viewModel.setup, names: [:], colour: viewModel.colour, style: .crewing,
                              selectedSeat: viewModel.selectedSeat, emptySeats: empty) { layout in
                ForEach(BoatRules.seatsSternToBow(viewModel.type), id: \.self) { seat in
                    let x = layout.xs[seat] ?? 0
                    Button {
                        viewModel.selectedSeat = seat
                    } label: {
                        Color.clear
                            .frame(width: Tokens.Boat.seatTapTarget, height: Tokens.Boat.seatTapTarget)
                            .contentShape(Circle())
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityHidden(true)
                    .position(x: x, y: Tokens.Boat.sidewaysHullCentre)
                    // Hung from the top, so a two-line note grows down, away from the blades.
                    let room = Tokens.Boat.crewHeight - Tokens.Boat.crewButtonTop
                    seatButton(seat)
                        .frame(width: Tokens.Boat.crewSeatSpacing - 6, height: room, alignment: .top)
                        .position(x: x, y: Tokens.Boat.crewButtonTop + room / 2)
                }
                if viewModel.rigging == .custom && isSweep {
                    ForEach(1...viewModel.type.rowers, id: \.self) { seat in
                        let up = viewModel.side(of: seat) == .stroke
                        let pin = Tokens.Boat.sidewaysHullCentre
                            + (up ? -1 : 1) * (Tokens.Boat.sidewaysHullHalfWidth + Tokens.Boat.sidewaysRiggerReach)
                        flipButton(seat)
                            .position(x: (layout.xs[seat] ?? 0) - Tokens.Boat.flipButtonOffset, y: pin)
                    }
                }
            }
            if isSweep {
                Text("Stroke side’s oars are above the boat, bow side’s below.")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .guidance()
            }
        }
        .padding(.horizontal, Tokens.Spacing.loose)
        .padding(.vertical, Tokens.Spacing.loose)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    /// ⇄: moves this seat's oar to the other side (custom rigging, decision 74).
    private func flipButton(_ seat: Int) -> some View {
        Button {
            viewModel.flip(seat)
        } label: {
            Text("⇄")
                .textStyle(Typography.chip)
                .foregroundStyle(Tokens.Accent.brand)
                .frame(width: Tokens.Boat.flipButton, height: Tokens.Boat.flipButton)
                .background(Circle().fill(Tokens.Surface.card))
                .background(Circle().fill(Tokens.Accent.brandSoft))
                .overlay { Circle().strokeBorder(Tokens.Accent.brand, lineWidth: 1) }
                .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                .contentShape(Circle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel("Move \(BoatRules.seatName(seat, type: viewModel.type).lowercased())'s oar to \(viewModel.side(of: seat) == .stroke ? "bow" : "stroke") side")
    }

    /// The button under a seat: the rower's first name and a note, or the empty seat, dashed.
    @ViewBuilder
    private func seatButton(_ seat: Int) -> some View {
        let person = viewModel.member(viewModel.seats[seat])
        let isSelected = viewModel.selectedSeat == seat
        let seatSide = viewModel.side(of: seat)
        let button = Button {
            viewModel.selectedSeat = seat
        } label: {
            Group {
                if let person {
                    VStack(spacing: 2) {
                        Text(BoatRules.firstName(person.displayName))
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if let note = BoatRules.seatNote(person.side, seat: seat, seatSide: seatSide) {
                            Text(note)
                                .textStyle(Typography.statLabel)
                                .fontWeight(.semibold)
                                .foregroundStyle(Tokens.Ink.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 6)
                                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Tokens.Surface.raised))
                        } else if let caption = BoatRules.role(seat, type: viewModel.type)
                                    ?? person.side.map({ $0 == .both ? "Both sides" : $0.label }) {
                            Text(caption)
                                .textStyle(Typography.statLabel)
                                .foregroundStyle(Tokens.Ink.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        Text(BoatRules.seatTitle(seat, type: viewModel.type))
                            .textStyle(Typography.meta)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let seatSide {
                            Text(seatSide.label)
                                .textStyle(Typography.statLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(Tokens.Accent.brand)
                    .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Tokens.Boat.seatButtonHeight)
            .background(Self.buttonShape.fill(person == nil ? Color.clear : Tokens.Base.ground))
            .overlay {
                if person == nil || isSelected {
                    Self.buttonShape.strokeBorder(Tokens.Accent.brand,
                                                  style: StrokeStyle(lineWidth: isSelected ? Tokens.Boat.selectedLineWidth : 1.5,
                                                                     dash: person == nil ? Tokens.Boat.dash : []))
                } else {
                    Self.buttonShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline)
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
                    if !candidates.isEmpty { Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline) }
                }
                if candidates.isEmpty {
                    Text("Nobody to offer yet: rowers appear here once they say they can make it.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Tokens.Spacing.card)
                }
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                    if index > 0 { Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline) }
                    candidateRow(candidate)
                }
            }
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .clipShape(Self.cardShape)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
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
                } else if candidate.isCox {
                    // A cox offered for a rowing seat (decision 78).
                    Text(RowingSide.cox.label)
                        .textStyle(Typography.chip)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Tokens.Surface.raised))
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
