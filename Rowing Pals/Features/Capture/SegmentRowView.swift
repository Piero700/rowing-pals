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
            thumbnail
            VStack(spacing: 0) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Spacing.gap), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                    editableField(
                        "Distance (m)", placeholder: "metres", text: $distanceText, keyboard: .numberPad,
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
                        Button(action: onNotMonitor) {
                            Text("Not a monitor photo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Tokens.Accent.brand)
                                .frame(minHeight: Tokens.Size.minTap)
                                .contentShape(Rectangle())
                        }
                    }
                    Spacer()
                    if let onRemove {
                        Button(role: .destructive, action: onRemove) {
                            Text("Remove piece")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Tokens.System.error)
                                .frame(minHeight: Tokens.Size.minTap)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Tokens.Spacing.loose)
        .background {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).fill(Tokens.Surface.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1)
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

    @ViewBuilder
    private var thumbnail: some View {
        // A manual piece has no photo, so no strip at all.
        if segment.photoJPEG != nil {
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
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.select, style: .continuous))
        }
    }

    /// A labelled field. Low-confidence fields get a cyan underline — never
    /// red, per CLAUDE.md: this is expected, not an error.
    private func editableField(
        _ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType,
        field: DraftSegment.Field, onCommit: @escaping () -> Void
    ) -> some View {
        let lowConfidence = segment.lowConfidenceFields.contains(field)
        return VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            TextField(placeholder, text: text, onEditingChanged: { isEditing in
                if !isEditing { onCommit() }
            })
                .font(.system(size: 16))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .keyboardType(keyboard)
                .focused(focusedField, equals: .field(segmentId: segment.id, field: field))
                .onSubmit(onCommit)
                .fieldBox(highlighted: lowConfidence)
        }
    }

    /// Average pace, derived from distance and time — not a field. Shows a
    /// dash until both are known.
    private var averageField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(paceDisplay == .split ? "Average /500m" : "Average watts")
            Text(segment.splitMs > 0 ? segment.splitMs.formattedPace(display: paceDisplay) : "—")
                .font(.system(size: 16))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .fieldBox(highlighted: false)
                .accessibilityLabel("Average pace, calculated from distance and time")
        }
    }

    /// The stroke rate field, with Confirm inside it for a photographed
    /// piece. Tapping Confirm commits any pending edit first, so what is
    /// confirmed is what is shown.
    private var rateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Stroke rate")
            HStack(spacing: 6) {
                TextField("spm", text: $rateText, onEditingChanged: { isEditing in
                    if !isEditing { commitRate() }
                })
                    .font(.system(size: 16))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                    .keyboardType(.decimalPad)
                    .frame(minWidth: 30)
                    .focused(focusedField, equals: .field(segmentId: segment.id, field: .rate))
                    .onSubmit(commitRate)
                    // Any real edit un-confirms. Compared to the stored rate, so the reformat
                    // that follows a commit ("19" → "19.0") doesn't cancel a confirmation.
                    .onChange(of: rateText) { _, newValue in
                        guard !segment.isManual else { return }
                        if Double(newValue) != segment.rate { segment.isRateConfirmed = false }
                    }
                if !segment.isManual {
                    confirmButton
                }
            }
            .padding(.trailing, segment.isManual ? 0 : -7)
            .fieldBox(highlighted: segment.lowConfidenceFields.contains(.rate))
        }
    }

    /// v3: a 40 pt glass pill inside the field, brand "Confirm" → "Checked" in the success colour.
    private var confirmButton: some View {
        Button {
            commitRate()
            guard segment.rate > 0 else { return }
            segment.isRateConfirmed = true
        } label: {
            Text(segment.isRateConfirmed ? "Checked" : "Confirm")
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(segment.isRateConfirmed ? Tokens.Accent.success : Tokens.Accent.brand)
                .padding(.horizontal, 12)
                .frame(minWidth: 80, minHeight: 40)
                .background {
                    if segment.isRateConfirmed { Capsule().fill(Tokens.Accent.successSoft) }
                }
                .glassSurface(in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(IconPressStyle())
        .layoutPriority(1)
        .accessibilityLabel(segment.isRateConfirmed ? "Stroke rate checked" : "Confirm stroke rate")
    }

    /// v3 field label: 12.5 pt, bold, muted.
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(Tokens.Ink.secondary)
            .lineLimit(1)
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

private extension View {
    /// v3 input box: 54 pt tall, card fill, 1 pt line, radius 24, 14 pt side padding. A value
    /// the reader wasn't sure of gets a 2 pt brand border — never red (CLAUDE.md: expected, not
    /// an error).
    func fieldBox(highlighted: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(shape.fill(Tokens.Surface.card))
            .overlay { shape.strokeBorder(highlighted ? Tokens.Accent.brand : Tokens.Surface.line, lineWidth: highlighted ? 2 : 1) }
    }
}
