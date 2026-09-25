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

/// One editable segment row in the review sheet — thumbnail, distance and
/// time, the read-only average, the stroke rate with its inline Confirm
/// button, and the Warmup/Main/Cooldown/Extra tag picker.
///
/// Redesign phase F (docs/design/rowing-pals-redesign-handoff-v2.md §2
/// Screen 05): the average /500m is no longer editable — it is derived from
/// distance and time and updates as either changes. The stroke rate has a
/// Confirm button embedded in the field, always required for a photographed
/// piece and cleared whenever the rate is edited. A manual piece has no
/// monitor to check against, so it has no Confirm.
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
    /// Marks the piece that will lead the post on the feed.
    var isLead = false
    /// Shown as a Remove button when the session has more than one piece.
    var onRemove: (() -> Void)?
    /// Shown when this piece's photo might not really be a monitor: moves it
    /// to the environment photos (docs/design/v2-decisions.md #9).
    var onNotMonitor: (() -> Void)?

    @State private var distanceText: String
    @State private var timeText: String
    @State private var rateText: String
    /// Redesign phase B — per-device display preference. The average shown
    /// here follows it, like every other read-only pace.
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    init(
        segment: Binding<DraftSegment>,
        focusedField: FocusState<ReviewField?>.Binding,
        isLead: Bool = false,
        onRemove: (() -> Void)? = nil,
        onNotMonitor: (() -> Void)? = nil
    ) {
        self._segment = segment
        self.focusedField = focusedField
        self.isLead = isLead
        self.onRemove = onRemove
        self.onNotMonitor = onNotMonitor
        let value = segment.wrappedValue
        // A manual piece starts blank — "0" and "0:00.0" would have to be
        // deleted before typing.
        _distanceText = State(initialValue: value.distanceM > 0 ? String(value.distanceM) : "")
        _timeText = State(initialValue: value.timeMs > 0 ? value.timeMs.formattedDurationMs : "")
        _rateText = State(initialValue: value.rate > 0 ? value.rate.formattedRate : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                thumbnail
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 3) {
                    editableField(
                        "Distance", placeholder: "metres", text: $distanceText, keyboard: .numberPad,
                        field: .distance, onCommit: commitDistance
                    )
                    editableField(
                        "Time", placeholder: "m:ss.t", text: $timeText, keyboard: .numbersAndPunctuation,
                        field: .time, onCommit: commitTime
                    )
                    averageField
                    rateField
                }
                // Use the row's full width: left to size itself the grid
                // shrinks, and the rate column is too narrow for its value
                // plus the Confirm button.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !segment.lowConfidenceFields.isEmpty {
                Text(lowConfidenceCaption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Tokens.Accent.brand)
            }
            Text(rateHelp)
                .font(.system(size: 12.5))
                .foregroundStyle(Tokens.Ink.secondary)
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
            if isLead {
                Label("Shown first on the feed", systemImage: "star")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            if onRemove != nil || onNotMonitor != nil {
                HStack(spacing: 16) {
                    if let onNotMonitor {
                        Button("Not a monitor photo", action: onNotMonitor)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.Accent.brand)
                            .frame(minHeight: 44)
                    }
                    Spacer()
                    if let onRemove {
                        Button("Remove piece", role: .destructive, action: onRemove)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.System.error)
                            .frame(minHeight: 44)
                    }
                }
                .buttonStyle(.plain)
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

    private var rateHelp: String {
        segment.isManual
            ? "Enter the stroke rate from your session."
            : "Check the stroke rate against your monitor, then tap Confirm."
    }

    private var thumbnail: some View {
        Group {
            if let data = segment.photoJPEG, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Tokens.Ink.primary.opacity(0.08))
                    .overlay {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    /// A labelled field. Low-confidence fields get a cyan underline — never
    /// red, per CLAUDE.md: this is expected, not an error.
    private func editableField(
        _ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType,
        field: DraftSegment.Field, onCommit: @escaping () -> Void
    ) -> some View {
        let lowConfidence = segment.lowConfidenceFields.contains(field)
        return VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            TextField(placeholder, text: text, onEditingChanged: { isEditing in
                if !isEditing { onCommit() }
            })
                .font(.system(size: 15, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .keyboardType(keyboard)
                .focused(focusedField, equals: .field(segmentId: segment.id, field: field))
                .onSubmit(onCommit)
                .overlay(alignment: .bottom) { fieldUnderline(lowConfidence: lowConfidence) }
        }
    }

    /// Average pace, derived from distance and time — not a field. Shows a
    /// dash until both are known.
    private var averageField: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(paceDisplay == .split ? "AVG /500M" : "AVG WATTS")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(segment.splitMs > 0 ? segment.splitMs.formattedPace(display: paceDisplay) : "—")
                .font(.system(size: 15, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityLabel("Average pace, calculated from distance and time")
        }
    }

    /// The stroke rate field, with Confirm inside it for a photographed
    /// piece. Tapping Confirm commits any pending edit first, so what is
    /// confirmed is what is shown.
    private var rateField: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Rate")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            HStack(spacing: 6) {
                TextField("spm", text: $rateText, onEditingChanged: { isEditing in
                    if !isEditing { commitRate() }
                })
                    .font(.system(size: 15, weight: .semibold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                    .keyboardType(.decimalPad)
                    .frame(minWidth: 36)
                    .focused(focusedField, equals: .field(segmentId: segment.id, field: .rate))
                    .onSubmit(commitRate)
                    // Any real edit un-confirms. Compared to the stored rate,
                    // so the reformat that follows a commit ("19" → "19.0")
                    // doesn't cancel a confirmation that was just given.
                    .onChange(of: rateText) { _, newValue in
                        guard !segment.isManual else { return }
                        if Double(newValue) != segment.rate { segment.isRateConfirmed = false }
                    }
                    .overlay(alignment: .bottom) {
                        fieldUnderline(lowConfidence: segment.lowConfidenceFields.contains(.rate))
                    }
                if !segment.isManual {
                    confirmButton
                }
            }
        }
    }

    private var confirmButton: some View {
        Button {
            commitRate()
            guard segment.rate > 0 else { return }
            segment.isRateConfirmed = true
        } label: {
            Text(segment.isRateConfirmed ? "Checked" : "Confirm")
                .font(.system(size: 11.5, weight: .bold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(segment.isRateConfirmed ? Tokens.Accent.success : Tokens.Base.dark)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill(segment.isRateConfirmed
                        ? Tokens.Accent.success.opacity(0.16)
                        : Tokens.Accent.brand)
                }
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
        .accessibilityLabel(segment.isRateConfirmed ? "Stroke rate checked" : "Confirm stroke rate")
    }

    /// Every editable field sits on a line so it reads as a field even when
    /// empty; a low-confidence reading gets a thicker brand line instead —
    /// never red (CLAUDE.md: this is expected, not an error).
    private func fieldUnderline(lowConfidence: Bool) -> some View {
        Rectangle()
            .fill(lowConfidence ? Tokens.Accent.brand.opacity(0.8) : Tokens.Surface.line)
            .frame(height: lowConfidence ? 2 : 1)
            .offset(y: 3)
    }

    private func commitDistance() {
        guard let parsed = Int(distanceText.filter(\.isNumber)) else {
            distanceText = segment.distanceM > 0 ? String(segment.distanceM) : ""
            return
        }
        distanceText = String(parsed)
        guard parsed != segment.distanceM else { return }
        segment.distanceM = parsed
        segment.recomputeSplit()
        segment.wasEdited = true
    }

    private func commitTime() {
        guard let parsed = DurationParsing.parseMs(timeText) else {
            timeText = segment.timeMs > 0 ? segment.timeMs.formattedDurationMs : ""
            return
        }
        timeText = parsed.formattedDurationMs
        guard parsed != segment.timeMs else { return }
        segment.timeMs = parsed
        segment.recomputeSplit()
        segment.wasEdited = true
    }

    private func commitRate() {
        guard let parsed = Double(rateText) else {
            rateText = segment.rate > 0 ? segment.rate.formattedRate : ""
            return
        }
        rateText = parsed.formattedRate
        guard parsed != segment.rate else { return }
        segment.rate = parsed
        segment.wasEdited = true
        if !segment.isManual { segment.isRateConfirmed = false }
    }
}
