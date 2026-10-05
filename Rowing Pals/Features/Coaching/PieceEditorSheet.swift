//
//  PieceEditorSheet.swift
//  Rowing Pals
//

import SwiftUI

/// Adding or changing one piece of a set workout (CoachWorkoutNew: "Each piece can be a
/// distance or a time, with reps, rest, target rate and target split"). The canvas lists the
/// pieces but doesn't draw this sheet; it follows the app's other forms.
struct PieceEditorSheet: View {
    let original: WorkoutPiece?
    let onSave: (WorkoutPiece) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var kind: WorkoutPiece.Kind
    @State private var valueText: String
    @State private var reps: Int
    @State private var restText: String
    @State private var rateMinText: String
    @State private var rateMaxText: String
    @State private var splitText: String

    private static let fieldShape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    init(piece: WorkoutPiece?, onSave: @escaping (WorkoutPiece) -> Void, onDelete: (() -> Void)?) {
        original = piece
        self.onSave = onSave
        self.onDelete = onDelete
        _kind = State(initialValue: piece?.kind ?? .distance)
        _valueText = State(initialValue: piece.map { $0.kind == .distance ? String($0.value) : WorkoutRules.clock($0.value) } ?? "")
        _reps = State(initialValue: piece?.reps ?? 1)
        _restText = State(initialValue: piece?.restMs.map(WorkoutRules.clock) ?? "")
        _rateMinText = State(initialValue: piece?.rateMin.map(String.init) ?? "")
        _rateMaxText = State(initialValue: piece?.rateMax.map(String.init) ?? "")
        _splitText = State(initialValue: piece?.splitMs.map(WorkoutRules.splitText) ?? "")
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
                Text(original == nil ? "Add piece" : "Piece")
                    .textStyle(Typography.navTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, Tokens.Spacing.tight)
            .padding(.top, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.minTap)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PillSegmentedControl(options: ["Distance", "Time"], selection: Binding(
                        get: { kind == .distance ? 0 : 1 },
                        set: { kind = $0 == 0 ? .distance : .time; valueText = "" }
                    ))
                    .padding(.top, Tokens.Spacing.loose)

                    label(kind == .distance ? "Distance" : "Time")
                    field(kind == .distance ? "2000" : "20:00", text: $valueText, unit: kind == .distance ? "m" : nil,
                          keyboard: kind == .distance ? .numberPad : .numbersAndPunctuation)

                    label("Reps")
                    HStack {
                        Text("\(reps)")
                            .textStyle(Typography.bodyV3)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.primary)
                        Spacer()
                        Stepper("Reps", value: $reps, in: 1...30)
                            .labelsHidden()
                    }
                    .padding(.horizontal, Tokens.Spacing.card)
                    .frame(minHeight: Tokens.Size.input)
                    .background(Self.fieldShape.fill(Tokens.Surface.card))
                    .overlay { Self.fieldShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }

                    label("Rest between reps (optional)")
                    field("5:00", text: $restText, unit: nil, keyboard: .numbersAndPunctuation)

                    label("Target rate (optional)")
                    HStack(spacing: Tokens.Spacing.loose) {
                        field("From", text: $rateMinText, unit: nil, keyboard: .numberPad)
                        field("To", text: $rateMaxText, unit: nil, keyboard: .numberPad)
                    }

                    label("Target split (optional)")
                    field("1:42", text: $splitText, unit: "/500m", keyboard: .numbersAndPunctuation)
                    Text("Leave the split empty and each rower gets their own target from the Pace Engine, for this zone and distance.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.tight)

                    if let problem {
                        Text(problem)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.System.error)
                            .padding(.horizontal, 4)
                            .padding(.top, Tokens.Spacing.loose)
                    }

                    if let onDelete {
                        Button("Remove piece") {
                            onDelete()
                            dismiss()
                        }
                        .buttonStyle(.rpDestructive)
                        .padding(.top, Tokens.Spacing.group)
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
        case .distance: Int(valueText.trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 100 && $0 <= 100_000 ? $0 : nil }
        case .time: DurationParsing.parseMs(valueText).flatMap { $0 >= 10_000 && $0 <= 7_200_000 ? $0 : nil }
        }
    }

    private func optionalMs(_ text: String) -> Int?? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .some(nil) }
        return DurationParsing.parseMs(trimmed).map { .some($0) } ?? nil
    }

    private func optionalRate(_ text: String) -> Int?? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .some(nil) }
        guard let rate = Int(trimmed), (10...50).contains(rate) else { return nil }
        return .some(rate)
    }

    /// The piece as entered, or nil while something can't be read.
    private var piece: WorkoutPiece? {
        guard let value, let rest = optionalMs(restText), let split = optionalMs(splitText),
              let rateMin = optionalRate(rateMinText), let rateMax = optionalRate(rateMaxText) else { return nil }
        if let rateMin, let rateMax, rateMin > rateMax { return nil }
        if let split, !(60_000...300_000).contains(split) { return nil }
        var piece = WorkoutPiece(kind: kind, value: value, reps: reps, restMs: rest, rateMin: rateMin,
                                 rateMax: rateMax ?? rateMin, splitMs: split)
        if let original { piece.id = original.id }
        return piece
    }

    private var problem: String? {
        if valueText.isEmpty { return nil }
        if value == nil {
            return kind == .distance ? "Enter a distance between 100 and 100,000 m." : "Enter a time like 20:00 (10 s to 2 hours)."
        }
        if optionalMs(restText) == nil { return "Enter the rest like 5:00." }
        if optionalRate(rateMinText) == nil || optionalRate(rateMaxText) == nil { return "Enter a rate between 10 and 50." }
        if let min = Int(rateMinText), let max = Int(rateMaxText), min > max { return "The first rate is above the second." }
        if case .some(.some(let split)) = optionalMs(splitText), !(60_000...300_000).contains(split) {
            return "Enter a split between 1:00 and 5:00."
        }
        if optionalMs(splitText) == nil { return "Enter the split like 1:42." }
        return nil
    }

    // MARK: - Building blocks

    private func label(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.group)
            .padding(.bottom, Tokens.Spacing.tight)
    }

    private func field(_ placeholder: String, text: Binding<String>, unit: String?, keyboard: UIKeyboardType) -> some View {
        HStack(spacing: Tokens.Spacing.tight) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textStyle(Typography.bodyV3)
                .tabularNumerals()
            if let unit {
                Text(unit)
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.input)
        .background(Self.fieldShape.fill(Tokens.Surface.card))
        .overlay { Self.fieldShape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
    }
}
