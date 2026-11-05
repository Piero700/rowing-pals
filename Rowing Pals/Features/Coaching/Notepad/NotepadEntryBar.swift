//
//  NotepadEntryBar.swift
//  Rowing Pals
//

import SwiftUI

/// The glass bar over the keyboard while a box on the notepad is being filled (decision 96): who
/// and which piece, Split or Time (Metres for a time piece), the number typed with
/// `DurationTextField` — tenths on the decimal key, 1 4 4 . 6 → "1:44.6" (decisions 53, 56) — an
/// optional rate, **Sat out**, **Clear** for a score already on the page, and **Next**, which saves
/// and moves down to the next erg, then on to the next piece.
struct NotepadEntryBar: View {
    @Bindable var viewModel: NotepadViewModel
    var focus: FocusState<NotepadField?>.Binding

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Notepad.entryRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            HStack(alignment: .center, spacing: Tokens.Spacing.tight) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.selectionTitle)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(viewModel.selectionNote)
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                GlassIconButton(icon: .chevronDown, accessibilityLabel: "Close") {
                    focus.wrappedValue = nil
                    viewModel.closeEntry()
                }
            }

            if viewModel.modes.count > 1 {
                PillSegmentedControl(
                    options: viewModel.modes.map { Self.label($0) },
                    selection: Binding(
                        get: { viewModel.modes.firstIndex(of: viewModel.mode) ?? 0 },
                        set: { index in
                            guard viewModel.modes.indices.contains(index) else { return }
                            viewModel.mode = viewModel.modes[index]
                            viewModel.durationText = ""
                            viewModel.metresText = ""
                            focus.wrappedValue = viewModel.mode == .metres ? .metres : .duration
                        }
                    ),
                    compact: true
                )
            }

            HStack(alignment: .top, spacing: Tokens.Spacing.tight) {
                VStack(alignment: .leading, spacing: 2) {
                    scoreField
                    Text(viewModel.typedHint)
                        .textStyle(Typography.statLabel)
                        .tabularNumerals()
                        .foregroundStyle(viewModel.hasTyped && viewModel.typedEntry == nil ? Tokens.System.error : Tokens.Ink.secondary)
                }
                .padding(.horizontal, Tokens.Spacing.loose)
                .padding(.vertical, Tokens.Spacing.tight)
                .formFieldBox()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate")
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                    TextField("–", text: $viewModel.rateText)
                        .keyboardType(.numberPad)
                        .focused(focus, equals: .rate)
                        .textStyle(Typography.selectedValue)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                        .onChange(of: viewModel.rateText) { _, value in
                            let digits = String(value.filter(\.isWholeNumber).prefix(2))
                            if digits != value { viewModel.rateText = digits }
                        }
                }
                .padding(.horizontal, Tokens.Spacing.loose)
                .padding(.vertical, Tokens.Spacing.tight)
                .formFieldBox()
                .frame(width: Tokens.Notepad.rateFieldWidth)
            }

            HStack(spacing: Tokens.Spacing.tight) {
                Button("Sat out") {
                    Task { await viewModel.markSatOut() }
                }
                .buttonStyle(.rpGlassCompact)
                if viewModel.canClear {
                    Button("Clear") {
                        Task { await viewModel.clearScore() }
                    }
                    .buttonStyle(.rpGlassCompact)
                }
                Button {
                    Task {
                        await viewModel.next()
                        if viewModel.selection == nil { focus.wrappedValue = nil }
                    }
                } label: {
                    Label(viewModel.nextTitle, icon: viewModel.nextSpot == nil ? .check : .chevronDown, size: Tokens.Icon.small)
                        .lineLimit(1)
                }
                .buttonStyle(.rpPrimary)
            }
        }
        .padding(Tokens.Spacing.card)
        .glassSurface(in: Self.shape)
        .padding(.horizontal, Tokens.Spacing.tight)
        .padding(.bottom, Tokens.Spacing.tight)
    }

    @ViewBuilder
    private var scoreField: some View {
        switch viewModel.mode {
        case .split, .time:
            DurationTextField(placeholder: "0:00.0", text: $viewModel.durationText, allowsTenths: true,
                              focus: focus, field: .duration)
                .textStyle(Typography.selectedValue)
                .tabularNumerals()
        case .metres:
            TextField("0", text: $viewModel.metresText)
                .keyboardType(.numberPad)
                .focused(focus, equals: .metres)
                .textStyle(Typography.selectedValue)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityLabel("Metres")
        }
    }

    private static func label(_ mode: NotepadRules.EntryMode) -> String {
        switch mode {
        case .split: "Split"
        case .time: "Time"
        case .metres: "Metres"
        }
    }
}
