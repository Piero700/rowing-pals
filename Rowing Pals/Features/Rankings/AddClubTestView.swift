//
//  AddClubTestView.swift
//  Rowing Pals
//

import SwiftUI

/// "+ Add test" (decision 28; docs/design/rowing-pals-redesign-handoff-v2.md §3 "Custom test
/// creation"): a club admin or above defines a distance, or a time in minutes or seconds. The
/// name is made from what they type ("750m", "3k", "20min", "30s"), checked against the standard
/// tests and the club's own before Add, and the new board starts empty.
struct AddClubTestView: View {
    private enum Kind: Int {
        case distance, minutes, seconds

        var unit: String {
            switch self {
            case .distance: "metres"
            case .minutes: "minutes"
            case .seconds: "seconds"
            }
        }

        var hint: String {
            switch self {
            case .distance: "A whole number of metres, e.g. 750 or 3000."
            case .minutes: "A whole number of minutes, e.g. 20."
            case .seconds: "A whole number of seconds, e.g. 30."
            }
        }
    }

    /// The club's tests already, so a duplicate is caught before Add.
    let existing: [ClubTest]
    /// Runs after the test is added.
    let onAdded: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .distance
    @State private var amount = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isAmountFocused: Bool

    private var value: Int? { Int(amount) }
    private var distanceM: Int? { kind == .distance ? value : nil }
    /// A time in seconds, whichever unit it was typed in.
    private var seconds: Int? {
        switch kind {
        case .distance: nil
        case .minutes: value.map { $0 * 60 }
        case .seconds: value
        }
    }
    private var problem: String? {
        ClubTest.problem(distanceM: distanceM, seconds: seconds, existing: existing)
    }
    private var label: String? { ClubTest.label(distanceM: distanceM, seconds: seconds) }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack {
                Text("Add a club test")
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.rpText)
            }

            Text("Every member of your club will see it under Test results and can post to it.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)

            PillSegmentedControl(options: ["Distance", "Minutes", "Seconds"], selection: kindSelection)

            amountField

            Group {
                if !amount.isEmpty, let problem {
                    Text(problem)
                        .foregroundStyle(Tokens.System.error)
                } else if let label {
                    Text("Shown as \(label). Results rank by \(kind == .distance ? "fastest time" : "furthest distance").")
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                } else {
                    Text(kind.hint)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            .textStyle(Typography.meta)

            if let errorMessage {
                Text(errorMessage)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.System.error)
            }

            Spacer(minLength: 0)

            Button(label.map { "Add \($0) test" } ?? "Add test") { Task { await save() } }
                .buttonStyle(.rpPrimary)
                .disabled(problem != nil || isSaving)
        }
        .padding(Tokens.Spacing.screen)
        .background(Tokens.Base.ground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { isAmountFocused = true }
        // A number in one unit means nothing in another.
        .onChange(of: kind) { amount = "" }
    }

    private var kindSelection: Binding<Int> {
        Binding(
            get: { kind.rawValue },
            set: { kind = Kind(rawValue: $0) ?? .distance }
        )
    }

    /// The v3 field: card fill, 1 pt line, radius 24, 52 pt tall, with the unit on the right.
    private var amountField: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack {
            TextField(kind == .distance ? "Distance" : "Length", text: $amount)
                .keyboardType(.numberPad)
                .focused($isAmountFocused)
                .tabularNumerals()
                .onChange(of: amount) { amount = String(amount.filter(\.isNumber).prefix(6)) }
            Text(kind.unit)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .textStyle(Typography.bodyV3)
        .foregroundStyle(Tokens.Ink.primary)
        .padding(.horizontal, Tokens.Spacing.card)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.input)
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await ClubTestService.create(distanceM: distanceM, seconds: seconds)
            await onAdded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
