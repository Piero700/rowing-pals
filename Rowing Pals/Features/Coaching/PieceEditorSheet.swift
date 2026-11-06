//
//  PieceEditorSheet.swift
//  Rowing Pals
//

import SwiftUI

/// Adding or changing one piece of a set workout (CoachWorkoutNew: "Each piece can be a
/// distance or a time, with reps, rest, target rate and target split"), in the compact grouped-rows
/// style (user, 2026-11-05): what the piece is, then its optional targets.
struct PieceEditorSheet: View {
    @Environment(\.showsGuidance) private var showsGuidance
    let original: WorkoutPiece?
    let onSave: (WorkoutPiece) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var kind: WorkoutPiece.Kind
    @State private var valueText: String
    @State private var reps: Int
    /// Time fields hold what they show ("5:00"); `DurationEntry` reads them back.
    @State private var restText: String
    @State private var rateMinText: String
    @State private var rateMaxText: String
    @State private var splitText: String
    @FocusState private var focusedTime: TimeField?

    private enum TimeField {
        case value, rest, split
    }

    /// The highest stroke rate a target can ask for (user, 2026-10-12).
    static let rateRange = 10...70

    init(piece: WorkoutPiece?, onSave: @escaping (WorkoutPiece) -> Void, onDelete: (() -> Void)?) {
        original = piece
        self.onSave = onSave
        self.onDelete = onDelete
        _kind = State(initialValue: piece?.kind ?? .distance)
        _valueText = State(initialValue: piece.map {
            $0.kind == .distance ? String($0.value) : Self.shown($0.value)
        } ?? "")
        _reps = State(initialValue: piece?.reps ?? 1)
        _restText = State(initialValue: piece?.restMs.map(Self.shown) ?? "")
        _rateMinText = State(initialValue: piece?.rateMin.map(String.init) ?? "")
        _rateMaxText = State(initialValue: piece?.rateMax.map(String.init) ?? "")
        _splitText = State(initialValue: piece?.splitMs.map(Self.shown) ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.rpText)
                    Spacer()
                    Button("Done") {
                        if let piece { onSave(piece); dismiss() }
                    }
                    .buttonStyle(.rpText)
                    .fontWeight(.semibold)
                    .disabled(piece == nil)
                }
                Text(original == nil ? "Add piece" : "Edit piece")
                    .textStyle(Typography.navTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.minTap)

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
                    PillSegmentedControl(options: ["Distance", "Time"], selection: Binding(
                        get: { kind == .distance ? 0 : 1 },
                        set: { kind = $0 == 0 ? .distance : .time; valueText = "" }
                    ))
                    .padding(.top, Tokens.Spacing.loose)

                    GroupedSection {
                        GroupedRow(label: kind == .distance ? "Distance" : "Time") {
                            if kind == .distance {
                                numberField("2000", text: $valueText, width: Tokens.Grouped.valueWidth,
                                            isInvalid: valueProblem != nil)
                                unit("m")
                            } else {
                                timeField("20:00", text: $valueText, field: .value, isInvalid: valueProblem != nil)
                            }
                        }
                        GroupedDivider()
                        GroupedRow(label: "Reps") {
                            Text("\(reps)")
                                .textStyle(Typography.detail)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.primary)
                            Stepper("Reps", value: $reps, in: 1...30)
                                .labelsHidden()
                        }
                    }

                    GroupedSection(
                        header: "Targets · optional",
                        // Helper text (decision 98): the footer goes once helper text is off.
                        footer: showsGuidance
                            ? "Split on Auto: each rower gets their own target from the Pace Engine, for this zone and distance."
                            : nil
                    ) {
                        GroupedRow(label: "Rest") {
                            timeField("None", text: $restText, field: .rest, isInvalid: restProblem != nil)
                        }
                        GroupedDivider()
                        GroupedRow(label: "Rate") {
                            numberField("From", text: $rateMinText, width: Tokens.Grouped.shortValueWidth,
                                        isInvalid: optionalRate(rateMinText) == nil)
                            unit("–")
                            numberField("To", text: $rateMaxText, width: Tokens.Grouped.shortValueWidth,
                                        isInvalid: optionalRate(rateMaxText) == nil || ratesOutOfOrder)
                        }
                        GroupedDivider()
                        GroupedRow(label: "Split") {
                            timeField("Auto", text: $splitText, field: .split, isInvalid: splitProblem != nil)
                            unit("/500m")
                        }
                    }

                    if let problem {
                        Text(problem)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.System.error)
                            .padding(.horizontal, Tokens.Grouped.rowPadding)
                    }

                    if let onDelete {
                        GroupedSection {
                            Button {
                                onDelete()
                                dismiss()
                            } label: {
                                Text("Remove piece")
                                    .textStyle(Typography.detail)
                                    .foregroundStyle(Tokens.System.error)
                                    .frame(maxWidth: .infinity, minHeight: Tokens.Grouped.rowHeight)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(IconPressStyle())
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, Tokens.Spacing.group)
            }
            .scrollIndicators(.hidden)
        }
        .background(Tokens.Base.ground)
        .presentationBackground(Tokens.Base.ground)
        .presentationDragIndicator(.visible)
        .dismissesKeyboardOnTap()
    }

    // MARK: - Reading the fields

    private var value: Int? {
        switch kind {
        case .distance: Int(valueText.trimmingCharacters(in: .whitespaces)).flatMap { (100...100_000).contains($0) ? $0 : nil }
        case .time: Self.milliseconds(valueText).flatMap { (10_000...7_200_000).contains($0) ? $0 : nil }
        }
    }

    /// "5:00" for 300,000 ms.
    private static func shown(_ ms: Int) -> String {
        DurationEntry.text(digits: DurationEntry.digits(milliseconds: ms))
    }

    /// A time field's milliseconds; nil when empty or unreadable.
    private static func milliseconds(_ text: String) -> Int? {
        DurationEntry.milliseconds(digits: DurationEntry.digits(from: text))
    }

    /// An optional time field: `.some(nil)` when empty, nil when it can't be read.
    private func optionalMs(_ text: String) -> Int?? {
        guard !DurationEntry.digits(from: text).isEmpty else { return .some(nil) }
        return Self.milliseconds(text).map { .some($0) } ?? nil
    }

    /// An optional rate: `.some(nil)` when empty, nil when it's not 10–70.
    private func optionalRate(_ text: String) -> Int?? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .some(nil) }
        guard let rate = Int(trimmed), Self.rateRange.contains(rate) else { return nil }
        return .some(rate)
    }

    /// The piece as entered, or nil while something can't be read.
    private var piece: WorkoutPiece? {
        guard valueProblem == nil, restProblem == nil, rateProblem == nil, splitProblem == nil,
              let value, case .some(let rest) = optionalMs(restText), case .some(let split) = optionalMs(splitText),
              case .some(let rateMin) = optionalRate(rateMinText), case .some(let rateMax) = optionalRate(rateMaxText)
        else { return nil }
        var piece = WorkoutPiece(kind: kind, value: value, reps: reps, restMs: rest, rateMin: rateMin,
                                 rateMax: rateMax ?? rateMin, splitMs: split)
        if let original { piece.id = original.id }
        return piece
    }

    private var valueProblem: String? {
        guard !valueText.isEmpty, value == nil else { return nil }
        return kind == .distance ? "Enter a distance between 100 and 100,000 m." : "Enter a time between 0:10 and 2:00:00."
    }

    private var restProblem: String? {
        optionalMs(restText) == nil ? "Enter the rest in minutes and seconds, like 5:00." : nil
    }

    private var rateProblem: String? {
        if optionalRate(rateMinText) == nil || optionalRate(rateMaxText) == nil {
            return "Invalid rate: enter a rate between \(Self.rateRange.lowerBound) and \(Self.rateRange.upperBound)."
        }
        if ratesOutOfOrder { return "The first rate is above the second." }
        return nil
    }

    private var ratesOutOfOrder: Bool {
        guard let min = Int(rateMinText), let max = Int(rateMaxText) else { return false }
        return min > max
    }

    private var splitProblem: String? {
        switch optionalMs(splitText) {
        case .none: "Enter the split in minutes and seconds, like 1:42."
        case .some(.some(let split)) where !(60_000...300_000).contains(split): "Enter a split between 1:00 and 5:00."
        default: nil
        }
    }

    private var problem: String? {
        valueProblem ?? restProblem ?? rateProblem ?? splitProblem
    }

    // MARK: - Building blocks

    /// A unit or separator beside a typed value ("m", "/500m", "–").
    private func unit(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.detail)
            .foregroundStyle(Tokens.Ink.secondary)
    }

    /// A time on the number pad, on the right of its row, with its colon put in as it's typed.
    private func timeField(_ placeholder: String, text: Binding<String>, field: TimeField,
                           isInvalid: Bool) -> some View {
        DurationTextField(placeholder: placeholder, text: text, focus: $focusedTime, field: field,
                          alignment: .trailing)
            .textStyle(Typography.detail)
            .tabularNumerals()
            .foregroundStyle(isInvalid ? Tokens.System.error : Tokens.Ink.primary)
            .frame(width: Tokens.Grouped.valueWidth, height: Tokens.Grouped.rowHeight)
    }

    /// Whole numbers on the number pad, on the right of their row; red while they can't be read.
    private func numberField(_ placeholder: String, text: Binding<String>, width: CGFloat,
                             isInvalid: Bool) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .textStyle(Typography.detail)
            .tabularNumerals()
            .foregroundStyle(isInvalid ? Tokens.System.error : Tokens.Ink.primary)
            .frame(width: width)
    }
}
