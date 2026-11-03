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

/// One editable segment row in the review sheet — thumbnail, distance, time,
/// the average, the stroke rate, and the Warmup/Main/Cooldown/Extra tag picker.
///
/// Decision 58 (2026-10-14): any two of distance, time and the average give the
/// third. Type the time and the average follows; type the average (a split, or
/// watts when that's the display preference) and the time follows — or, with
/// no distance yet, the distance. Whichever of time and average was typed last
/// is the one kept when the distance changes. The stroke rate has no Confirm
/// button (user, 2026-11-03): a rower who cares checks it and edits it.
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
    @State private var splitText: String
    /// The piece's distance, time and split when a time or average field was entered: put back
    /// if that field is left unreadable.
    @State private var beforeEditing: Snapshot?
    /// The average was typed more recently than the time: a new distance keeps the average and
    /// works out the time, rather than the other way round.
    @State private var splitTypedLast = false

    private struct Snapshot: Equatable {
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int
    }

    /// The splits a rower can type: 1:00 to 9:59.9 per 500 m.
    private static let splitRange = 60_000...599_900
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
        _timeText = State(initialValue: Self.shown(value.timeMs))
        _rateText = State(initialValue: value.rate > 0 ? value.rate.formattedRate : "")
        _splitText = State(initialValue: Self.shownSplit(value.splitMs, display: PaceDisplay.current))
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
                    timeField
                    averageField
                    rateField
                }
                // Use the row's full width: left to size itself the grid shrinks.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if timeIsUnreadable {
                Text("That isn't a time: minutes and seconds go up to 59.")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.System.error)
            }
            if splitIsUnreadable {
                Text(paceDisplay == .split
                     ? "Enter an average between 1:00 and 9:59.9 per 500m."
                     : "Enter average watts between 2 and 1,620.")
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.System.error)
            }
            if !segment.lowConfidenceFields.isEmpty {
                Text(lowConfidenceCaption)
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Accent.brand)
            }
            if segment.isManual {
                Text("Enter the stroke rate from your session.")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
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
            if isLead {
                Label("Shown first on the feed", icon: .star)
                    .textStyle(Typography.fieldLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            if onRemove != nil || onNotMonitor != nil {
                HStack(spacing: 16) {
                    if let onNotMonitor {
                        Button(action: onNotMonitor) {
                            Text("Not a monitor photo")
                                .textStyle(Typography.pill)
                                .foregroundStyle(Tokens.Accent.brand)
                                .frame(minHeight: Tokens.Size.minTap)
                                .contentShape(Rectangle())
                        }
                    }
                    Spacer()
                    if let onRemove {
                        Button(role: .destructive, action: onRemove) {
                            Text("Remove piece")
                                .textStyle(Typography.pill)
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
                        RPIconView(icon: .pencil, size: Tokens.Icon.small)
                            .textStyle(Typography.rowTitle)
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
                .textStyle(Typography.bodyV3)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .keyboardType(keyboard)
                .focused(focusedField, equals: .field(segmentId: segment.id, field: field))
                .onSubmit(onCommit)
                .fieldBox(highlighted: lowConfidence)
        }
    }

    /// The time as the monitor shows it, typed like every time in the app (user, 2026-10-14):
    /// digits only, the colon put in as you type, the decimal key for the tenth — 7 0 2 . 4 reads
    /// "7:02.4". Each readable keystroke goes straight into the piece, so the average beside it
    /// follows and Post always has what's shown; leaving an unreadable time puts back the one
    /// from before the field was entered.
    private var timeField: some View {
        let field = ReviewField.field(segmentId: segment.id, field: .time)
        return VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Time")
            DurationTextField(placeholder: "0:00.0", text: $timeText, allowsTenths: true,
                              focus: focusedField, field: field)
                .textStyle(Typography.bodyV3)
                .tabularNumerals()
                .fieldBox(highlighted: segment.lowConfidenceFields.contains(.time), invalid: timeIsUnreadable)
        }
        // Only typing counts: the text also changes when the average sets the time.
        .onChange(of: timeText) { if focusedField.wrappedValue == field { commitTime(leaving: false) } }
        .onChange(of: focusedField.wrappedValue, initial: true) { old, new in
            if new == field, old != field || beforeEditing == nil { beforeEditing = snapshot }
            if old == field, new != field { commitTime(leaving: true) }
        }
    }

    private var snapshot: Snapshot {
        Snapshot(distanceM: segment.distanceM, timeMs: segment.timeMs, splitMs: segment.splitMs)
    }

    /// Puts the piece back as it was when the field was entered.
    private func restoreBeforeEditing() {
        guard let before = beforeEditing else { return }
        segment.distanceM = before.distanceM
        segment.timeMs = before.timeMs
        segment.splitMs = before.splitMs
        distanceText = before.distanceM > 0 ? String(before.distanceM) : ""
        timeText = Self.shown(before.timeMs)
        splitText = Self.shownSplit(before.splitMs, display: paceDisplay)
    }

    /// Something typed that isn't a time ("0:75").
    private var timeIsUnreadable: Bool {
        !timeText.isEmpty && Self.milliseconds(timeText) == nil
    }

    /// "7:02.4" for 422,400 ms; "" for none.
    private static func shown(_ ms: Int) -> String {
        ms > 0 ? DurationEntry.text(entry: DurationEntry.entry(milliseconds: ms)) : ""
    }

    private static func milliseconds(_ text: String) -> Int? {
        DurationEntry.milliseconds(entry: DurationEntry.entry(from: text, allowsTenths: true)).flatMap { $0 > 0 ? $0 : nil }
    }

    /// The average: worked out from distance and time, or typed — a split like every time in the
    /// app (1 4 5 . 2 reads "1:45.2"), or whole watts when that's the display preference — and
    /// then the time (or, with no distance, the distance) follows (decision 58).
    private var averageField: some View {
        let field = ReviewField.field(segmentId: segment.id, field: .split)
        return VStack(alignment: .leading, spacing: 6) {
            fieldLabel(paceDisplay == .split ? "Average /500m" : "Average watts")
            Group {
                if paceDisplay == .split {
                    DurationTextField(placeholder: "0:00.0", text: $splitText, allowsTenths: true,
                                      focus: focusedField, field: field)
                } else {
                    TextField("watts", text: $splitText)
                        .keyboardType(.numberPad)
                        .focused(focusedField, equals: field)
                        .onChange(of: splitText) { _, new in
                            let clean = String(new.filter(\.isWholeNumber).prefix(4))
                            if clean != new { splitText = clean }
                        }
                }
            }
            .textStyle(Typography.bodyV3)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.primary)
            .fieldBox(highlighted: false, invalid: splitIsUnreadable)
        }
        // Only typing counts: the text also changes when distance or time set the average.
        .onChange(of: splitText) { if focusedField.wrappedValue == field { commitSplit(leaving: false) } }
        .onChange(of: focusedField.wrappedValue, initial: true) { old, new in
            if new == field, old != field || beforeEditing == nil { beforeEditing = snapshot }
            if old == field, new != field { commitSplit(leaving: true) }
        }
        // Distance and time can change the average while this field isn't being typed in.
        .onChange(of: segment.splitMs) { _, new in
            guard focusedField.wrappedValue != field else { return }
            splitText = Self.shownSplit(new, display: paceDisplay)
        }
        .onChange(of: paceDisplay) { _, display in
            splitText = Self.shownSplit(segment.splitMs, display: display)
        }
    }

    /// The typed average as a split, or nil if it isn't one in range.
    private func typedSplitMs(_ text: String) -> Int? {
        let ms: Int? = paceDisplay == .split
            ? Self.milliseconds(text)
            : Int(text).flatMap { PaceDisplay.splitMs(watts: $0) }
        return ms.flatMap { Self.splitRange.contains($0) ? $0 : nil }
    }

    /// Something typed in the average that isn't a split in range.
    private var splitIsUnreadable: Bool {
        !splitText.isEmpty && typedSplitMs(splitText) == nil
    }

    /// "1:45.2", or "186" in watts; "" for none.
    private static func shownSplit(_ ms: Int, display: PaceDisplay) -> String {
        guard ms > 0 else { return "" }
        return display == .split ? shown(ms) : String(PaceDisplay.watts(splitMs: ms))
    }

    /// Takes a typed average into the piece: the time follows from the distance, or — with no
    /// distance yet — the distance from the time. On `leaving`, the text is tidied or, if it
    /// isn't an average, the piece goes back to how it was.
    private func commitSplit(leaving: Bool) {
        guard let parsed = typedSplitMs(splitText) else {
            if leaving {
                if splitText.isEmpty || beforeEditing == nil {
                    splitText = Self.shownSplit(segment.splitMs, display: paceDisplay)
                } else {
                    restoreBeforeEditing()
                }
            }
            return
        }
        if leaving { splitText = Self.shownSplit(parsed, display: paceDisplay) }
        guard parsed != segment.splitMs else { return }
        segment.splitMs = parsed
        splitTypedLast = true
        if segment.distanceM > 0 {
            segment.timeMs = DraftSegment.timeMs(splitMs: parsed, distanceM: segment.distanceM)
            timeText = Self.shown(segment.timeMs)
        } else if segment.timeMs > 0 {
            segment.distanceM = DraftSegment.distanceM(timeMs: segment.timeMs, splitMs: parsed)
            distanceText = String(segment.distanceM)
        }
        segment.wasEdited = true
    }

    /// The stroke rate field.
    private var rateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Stroke rate")
            TextField("spm", text: $rateText, onEditingChanged: { isEditing in
                if !isEditing { commitRate() }
            })
                .textStyle(Typography.bodyV3)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .keyboardType(.decimalPad)
                .frame(minWidth: 30)
                .focused(focusedField, equals: .field(segmentId: segment.id, field: .rate))
                .onSubmit(commitRate)
                .fieldBox(highlighted: segment.lowConfidenceFields.contains(.rate))
        }
    }

    /// v3 field label: 12.5 pt, bold, muted.
    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.fieldLabel)
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
        // Keep whichever of time and average was typed last; work out the other (decision 58).
        if segment.splitMs > 0, splitTypedLast || segment.timeMs == 0 {
            segment.timeMs = DraftSegment.timeMs(splitMs: segment.splitMs, distanceM: parsed)
            timeText = Self.shown(segment.timeMs)
        } else {
            segment.recomputeSplit()
        }
        segment.wasEdited = true
    }

    /// Takes a readable time into the piece. On `leaving` the field, the text is tidied ("7:02."
    /// → "7:02") or, if it isn't a time, the time from before the field was entered goes back —
    /// not whatever was passed through on the way ("0:07" while typing 7 5).
    private func commitTime(leaving: Bool) {
        guard let parsed = Self.milliseconds(timeText) else {
            guard leaving else { return }
            if beforeEditing != nil {
                restoreBeforeEditing()
            } else {
                timeText = Self.shown(segment.timeMs)
            }
            return
        }
        if leaving { timeText = Self.shown(parsed) }
        guard parsed != segment.timeMs else { return }
        segment.timeMs = parsed
        splitTypedLast = false
        if segment.distanceM > 0 {
            segment.recomputeSplit()
        } else if segment.splitMs > 0 {
            // No distance yet: the average typed earlier gives it (decision 58).
            segment.distanceM = DraftSegment.distanceM(timeMs: parsed, splitMs: segment.splitMs)
            distanceText = String(segment.distanceM)
        }
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
    }
}

private extension View {
    /// v3 input box: 54 pt tall, card fill, 1 pt line, radius 24, 14 pt side padding. A value
    /// the reader wasn't sure of gets a 2 pt brand border — never red (CLAUDE.md: expected, not
    /// an error). Red is only for something typed that can't be read.
    func fieldBox(highlighted: Bool, invalid: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        let edge = invalid ? Tokens.System.error : highlighted ? Tokens.Accent.brand : Tokens.Surface.line
        return padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(shape.fill(Tokens.Surface.card))
            .overlay { shape.strokeBorder(edge, lineWidth: highlighted || invalid ? 2 : 1) }
    }
}
