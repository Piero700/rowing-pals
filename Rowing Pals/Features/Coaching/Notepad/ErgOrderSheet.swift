//
//  ErgOrderSheet.swift
//  Rowing Pals
//

import SwiftUI

/// Putting the notepad's rowers in erg order (decision 96): drag a rower to match the line of
/// ergs; **Next** walks down this order. Saved with the page, for every coach.
struct ErgOrderSheet: View {
    let viewModel: NotepadViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(viewModel.rowers.enumerated()), id: \.element.id) { index, rower in
                        HStack(spacing: Tokens.Spacing.loose) {
                            Text("\(index + 1)")
                                .textStyle(Typography.meta)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.faint)
                                .frame(width: Tokens.Notepad.ergColumn, alignment: .trailing)
                            Text(rower.name)
                                .textStyle(Typography.rowTitle)
                                .foregroundStyle(Tokens.Ink.primary)
                        }
                        .listRowBackground(Tokens.Surface.card)
                        .accessibilityElement(children: .combine)
                    }
                    .onMove { source, destination in
                        viewModel.moveRowers(from: source, to: destination)
                    }
                } footer: {
                    Text("Drag rowers to match the ergs. Next walks down this order, and every coach sees it.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .guidance()
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Tokens.Base.ground)
            .navigationTitle("Erg order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Tokens.Accent.brand)
    }
}
