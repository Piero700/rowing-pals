//
//  SegmentRowView.swift
//  Rowing Pals
//

import SwiftUI

/// Which field of which draft segment currently has keyboard focus — shared
/// between `ReviewSheetView` and every `SegmentRowView` it hosts, so the
/// review sheet can pre-focus a low-confidence field on appear.
enum ReviewField: Hashable {
    case field(segmentId: DraftSegment.ID, field: DraftSegment.Field)
}

/// One editable segment row in the review sheet — thumbnail, the four
/// inline-editable fields, and the Warmup/Main/Cooldown/Extra tag picker.
///
/// Owns its own text buffers (`distanceText` etc.) rather than formatting
/// straight from the bound segment on every render: a `Binding<String>`
/// computed from the model reformats on each keystroke and fights the
/// user's cursor mid-edit (typing "1:0" gets stomped back to "0:00.0" the
/// instant "1:0" fails to parse as a complete duration). Buffers are seeded
/// once from the model and only pushed back into it when a keystroke
/// produces something parseable.
struct SegmentRowView: View {
    @Binding var segment: DraftSegment
    var focusedField: FocusState<ReviewField?>.Binding

    @State private var distanceText: String
    @State private var timeText: String
    @State private var splitText: String
    @State private var rateText: String

    init(segment: Binding<DraftSegment>, focusedField: FocusState<ReviewField?>.Binding) {
        self._segment = segment
        self.focusedField = focusedField
        _distanceText = State(initialValue: String(segment.wrappedValue.distanceM))
        _timeText = State(initialValue: segment.wrappedValue.timeMs.formattedDurationMs)
        _splitText = State(initialValue: segment.wrappedValue.splitMs.formattedDurationMs)
        _rateText = State(initialValue: segment.wrappedValue.rate.formattedRate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                thumbnail
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 3) {
                    editableField(
                        "Distance", text: $distanceText, keyboard: .numberPad,
                        field: .distance, onCommit: commitDistance
                    )
                    editableField(
                        "Time", text: $timeText, keyboard: .numbersAndPunctuation,
                        field: .time, onCommit: commitTime
                    )
                    editableField(
                        "/500m", text: $splitText, keyboard: .numbersAndPunctuation,
                        field: .split, onCommit: commitSplit
                    )
                    editableField(
                        "Rate", text: $rateText, keyboard: .decimalPad,
                        field: .rate, onCommit: commitRate
                    )
                }
            }
            if !segment.lowConfidenceFields.isEmpty {
                Text(lowConfidenceCaption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Tokens.Accent.signal)
            }
            HStack(spacing: 6) {
                ForEach(SegmentLabel.allCases, id: \.self) { tag in
                    Button {
                        guard tag != segment.label else { return }
                        segment.label = tag
                        segment.wasEdited = true
                    } label: {
                        FilterChip(label: tag.rawValue.uppercased(), isSelected: segment.label == tag)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.05))
        }
    }

    private var lowConfidenceCaption: String {
        let count = segment.lowConfidenceFields.count
        return "\(count) value\(count == 1 ? "" : "s") read with low confidence — worth a check."
    }

    private var thumbnail: some View {
        Group {
            if let uiImage = UIImage(data: segment.photoJPEG) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Tokens.Ink.primary.opacity(0.08))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    /// A labelled field. Low-confidence fields get a cyan underline — never
    /// red, per CLAUDE.md: this is expected, not an error.
    private func editableField(
        _ label: String, text: Binding<String>, keyboard: UIKeyboardType,
        field: DraftSegment.Field, onCommit: @escaping () -> Void
    ) -> some View {
        let lowConfidence = segment.lowConfidenceFields.contains(field)
        return VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            TextField("", text: text, onEditingChanged: { isEditing in
                if !isEditing { onCommit() }
            })
                .font(.system(size: 15, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .keyboardType(keyboard)
                .focused(focusedField, equals: .field(segmentId: segment.id, field: field))
                .onSubmit(onCommit)
                .overlay(alignment: .bottom) {
                    if lowConfidence {
                        Rectangle()
                            .fill(Tokens.Accent.signal.opacity(0.8))
                            .frame(height: 2)
                            .offset(y: 2)
                    }
                }
        }
    }

    private func commitDistance() {
        guard let parsed = Int(distanceText.filter(\.isNumber)) else {
            distanceText = String(segment.distanceM)
            return
        }
        distanceText = String(parsed)
        guard parsed != segment.distanceM else { return }
        segment.distanceM = parsed
        segment.wasEdited = true
    }

    private func commitTime() {
        guard let parsed = DurationParsing.parseMs(timeText) else {
            timeText = segment.timeMs.formattedDurationMs
            return
        }
        timeText = parsed.formattedDurationMs
        guard parsed != segment.timeMs else { return }
        segment.timeMs = parsed
        segment.wasEdited = true
    }

    private func commitSplit() {
        guard let parsed = DurationParsing.parseMs(splitText) else {
            splitText = segment.splitMs.formattedDurationMs
            return
        }
        splitText = parsed.formattedDurationMs
        guard parsed != segment.splitMs else { return }
        segment.splitMs = parsed
        segment.wasEdited = true
    }

    private func commitRate() {
        guard let parsed = Double(rateText) else {
            rateText = segment.rate.formattedRate
            return
        }
        rateText = parsed.formattedRate
        guard parsed != segment.rate else { return }
        segment.rate = parsed
        segment.wasEdited = true
    }
}
