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
    var photoJPEG: Data
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

        lowConfidenceFields = lowConfidence
        ocrConfidence = confidences.reduce(0, +) / Double(confidences.count)
    }
}
