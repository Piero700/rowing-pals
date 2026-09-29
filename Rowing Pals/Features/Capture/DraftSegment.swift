//
//  DraftSegment.swift
//  Rowing Pals
//

import Foundation

/// A segment as it exists in the review sheet, before posting — one photo
/// plus its OCR-extracted (or hand-corrected) fields, not yet written to
/// Supabase. `Segment` (Core/Models) is the posted row; this is its draft.
struct DraftSegment: Identifiable {
    enum Field: Hashable {
        case distance, time, split, rate
    }

    let id = UUID()
    var label: SegmentLabel
    /// Nil for a manually entered segment — there is no monitor photo.
    var photoJPEG: Data?
    var distanceM: Int
    var timeMs: Int
    var splitMs: Int
    var rate: Double
    /// The mean of the four raw OCR confidences at the moment this segment
    /// was created — stored on the posted row's `ocr_confidence` regardless
    /// of any hand edits since, as a record of how much to trust the photo.
    let ocrConfidence: Double
    /// Fields the OCR pass returned with no reading, or read with low
    /// confidence — these get the cyan underline and initial focus in the
    /// review sheet, never red (CLAUDE.md: this is expected, not an error).
    var lowConfidenceFields: Set<Field>
    var wasEdited = false
    /// The rower has checked this segment's stroke rate against the monitor.
    /// Required before posting a photographed segment, and cleared whenever
    /// the rate is edited (prototype: "Check the stroke rate against your
    /// monitor, then tap Confirm."). A manual segment has no monitor to
    /// check against, so it starts confirmed.
    var isRateConfirmed = false
    var isManual: Bool { photoJPEG == nil }

    /// Builds a segment from one photo's OCR output. Any field with no
    /// reading defaults to 0 so the user has something to type over, and is
    /// flagged low-confidence alongside anything Vision was merely unsure
    /// about.
    init(label: SegmentLabel, photoJPEG: Data, fields: ParsedMonitorFields) {
        self.label = label
        self.photoJPEG = photoJPEG

        var lowConfidence: Set<Field> = []
        var confidences: [Double] = []

        func resolve<Value>(_ field: MonitorField<Value>, _ key: Field, default defaultValue: Value) -> Value {
            confidences.append(field.confidence)
            if field.value == nil || field.confidence < 0.5 {
                lowConfidence.insert(key)
            }
            return field.value ?? defaultValue
        }

        distanceM = resolve(fields.distanceM, .distance, default: 0)
        timeMs = resolve(fields.elapsedTimeMs, .time, default: 0)
        splitMs = resolve(fields.splitMs, .split, default: 0)
        rate = resolve(fields.rate, .rate, default: 0)

        // The average is derived from distance and time, never read, so it
        // can't be "low confidence" — nothing for the rower to check.
        lowConfidence.remove(.split)
        lowConfidenceFields = lowConfidence
        ocrConfidence = confidences.reduce(0, +) / Double(confidences.count)
        // The monitor's own split is not trusted: the average is always
        // derived from distance and time, so the three can never disagree.
        recomputeSplit()
    }

    /// A blank segment for "Enter session manually": no photo, nothing read,
    /// nothing to confirm.
    init(manualLabel label: SegmentLabel) {
        self.label = label
        photoJPEG = nil
        distanceM = 0
        timeMs = 0
        splitMs = 0
        rate = 0
        ocrConfidence = 0
        lowConfidenceFields = []
        isRateConfirmed = true
    }

    /// Average pace per 500 m, derived from distance and time — read-only in
    /// the UI ("Average /500m now read-only, auto-computed as distance/time
    /// change"). Zero until both are known.
    mutating func recomputeSplit() {
        guard distanceM > 0, timeMs > 0 else {
            splitMs = 0
            return
        }
        splitMs = Int((Double(timeMs) / (Double(distanceM) / 500)).rounded())
    }
}
