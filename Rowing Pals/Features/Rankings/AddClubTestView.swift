//
//  AddClubTestView.swift
//  Rowing Pals
//

import SwiftUI

/// "+ Add test" (decision 28; docs/design/rowing-pals-redesign-handoff-v2.md §3 "Custom test
/// creation"): a club admin or above defines a distance, or a time typed like every time in the
/// app — the colon put in as you type, 2 0 0 0 → "20:00", 3 0 → "0:30" (user, 2026-10-14). The
/// name is made from it ("750m", "3k", "20min", "30s"), checked against the standard tests and
/// the club's own before Add, and the new board starts empty.
struct AddClubTestView: View {
    private enum Kind: Int {
        case distance, time

        var hint: String {
            switch self {
            case .distance: "A whole number of metres, e.g. 750 or 3000."
            case .time: "Minutes and seconds, e.g. 20:00 or 0:30."
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
    @FocusState private var focusedKind: Kind?

    private var distanceM: Int? { kind == .distance ? Int(amount) : nil }
    /// The time in whole seconds, from the shown "20:00".
    private var seconds: Int? {
        guard kind == .time else { return nil }
        return DurationEntry.milliseconds(digits: DurationEntry.digits(from: amount)).map { $0 / 1000 }
    }
    private var problem: String? {
        if kind == .time, !amount.isEmpty, seconds == nil {
            return "That isn't a time: minutes and seconds go up to 59."
        }
        return ClubTest.problem(distanceM: distanceM, seconds: seconds, existing: existing)
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
                .guidance()

            PillSegmentedControl(options: ["Distance", "Time"], selection: kindSelection)

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
        .onAppear { focusedKind = kind }
        // A number in one unit means nothing in another.
        .onChange(of: kind) {
            amount = ""
            focusedKind = kind
        }
    }

    private var kindSelection: Binding<Int> {
        Binding(
            get: { kind.rawValue },
            set: { kind = Kind(rawValue: $0) ?? .distance }
        )
    }

    /// One grouped row: a distance has "m" on the right; a time shows its colon as it's typed.
    private var amountField: some View {
        GroupedSection {
            GroupedRow(label: kind == .distance ? "Distance" : "Time") {
                if kind == .distance {
                    TextField("2000", text: $amount)
                        .keyboardType(.numberPad)
                        .focused($focusedKind, equals: .distance)
                        .multilineTextAlignment(.trailing)
                        .textStyle(Typography.detail)
                        .tabularNumerals()
                        .onChange(of: amount) { amount = String(amount.filter(\.isNumber).prefix(6)) }
                    Text("m")
                        .textStyle(Typography.detail)
                        .foregroundStyle(Tokens.Ink.secondary)
                } else {
                    DurationTextField(placeholder: "20:00", text: $amount, focus: $focusedKind, field: .time,
                                      alignment: .trailing)
                        .textStyle(Typography.detail)
                        .tabularNumerals()
                        .frame(width: Tokens.Grouped.valueWidth, height: Tokens.Grouped.rowHeight)
                }
            }
        }
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
