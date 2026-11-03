//
//  AddBoatSheet.swift
//  Rowing Pals
//

import SwiftUI

/// Add a boat to a water session (CoachAddBoat; decision 70): the saved boats, each checked against
/// who's available ("All 4 available", "Lucy can't make it: swap them after adding", "Joe is
/// already in M1 four"), or New boat. A saved boat already in the session isn't offered again
/// (user, 2026-11-03).
struct AddBoatSheet: View {
    let viewModel: WaterSessionViewModel
    let onAdd: (SavedBoat) -> Void
    let onNew: () -> Void

    @Environment(\.dismiss) private var dismiss

    private static let rowShape = RoundedRectangle(cornerRadius: Tokens.Radius.panel, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
                HStack {
                    Text("Add a boat")
                        .textStyle(Typography.selectedValue)
                        .foregroundStyle(Tokens.Ink.primary)
                    Spacer(minLength: 0)
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.rpText)
                }
                Text("\(viewModel.whenText) · \(viewModel.available == nil ? "no practice or race at this time to check against" : "checked against who’s available")")
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, 4)
                if viewModel.savedBoats.isEmpty {
                    Text("No saved boats yet. Make a new one, and turn on Keep in Saved boats to add it in a tap next time.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                } else if viewModel.addableSavedBoats.isEmpty {
                    Text("Every saved boat is in this session already.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                ForEach(viewModel.addableSavedBoats) { boat in
                    row(boat)
                }
                Button {
                    onNew()
                } label: {
                    Label("New boat", icon: .plus)
                }
                .buttonStyle(.rpGlass)
                .padding(.top, Tokens.Spacing.tight)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.group)
            .padding(.bottom, Tokens.Spacing.loose)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Tokens.Base.ground)
    }

    private func row(_ boat: SavedBoat) -> some View {
        let check = BoatRules.savedBoatCheck(boat, names: viewModel.names, available: viewModel.available,
                                             cant: viewModel.cant, seatedIn: viewModel.seatedIn)
        return Button {
            onAdd(boat)
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                Text(boat.boatType.label)
                    .textStyle(Typography.rowTitle)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Tokens.Schedule.iconTile, height: Tokens.Schedule.iconTile)
                    .background(RoundedRectangle(cornerRadius: Tokens.Schedule.iconTileRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text(boat.name)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(BoatRules.crewLine(boat.seats, names: viewModel.names))
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(check.text)
                        .textStyle(Typography.statLabel)
                        .fontWeight(check.isProblem ? .semibold : .regular)
                        .tabularNumerals()
                        .foregroundStyle(check.isProblem ? Tokens.Ink.primary : Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RPIconView(icon: .plusCircle, size: Tokens.Icon.large)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Accent.brand)
            }
            .padding(Tokens.Spacing.loose)
            .background(Self.rowShape.fill(Tokens.Surface.card))
            .overlay { Self.rowShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .contentShape(Self.rowShape)
        }
        .buttonStyle(IconPressStyle())
        .disabled(viewModel.isWorking)
    }
}
