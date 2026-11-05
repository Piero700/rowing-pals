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
    /// An interval session's rep distance, read off the monitor's workout title
    /// ("8x500m/1:00r" → 500). Nil for a continuous piece, a timed-rep workout or a manual entry.
    var repDistanceM: Int?
    /// The split of each row the monitor showed under a continuous piece (a 2k's four 500m
    /// splits), read off the photo (NP3). Nil for a manual entry or an interval workout.
    var splitRowsMs: [Int]?
    /// The metres read off the photo, to tell whether the split rows still belong to this piece.
    private(set) var readDistanceM: Int?
    var isManual: Bool { photoJPEG == nil }

    /// The split rows to post: only while the metres are still the ones read off the photo, since
    /// the rows are that distance's splits. Fixing a misread time or changing the label keeps them.
    var postedSplitRowsMs: [Int]? {
        guard let splitRowsMs, let readDistanceM, readDistanceM == distanceM, distanceM > 0 else { return nil }
        return splitRowsMs
    }

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
        repDistanceM = fields.repDistanceM
        splitRowsMs = fields.splitRowsMs
        readDistanceM = fields.distanceM.value

        // The average is derived from distance and time, never read, so it
        // can't be "low confidence" — nothing for the rower to check.
        lowConfidence.remove(.split)
        lowConfidenceFields = lowConfidence
        ocrConfidence = confidences.reduce(0, +) / Double(confidences.count)
        // The monitor's own split is not trusted: the average is always
        // derived from distance and time, so the three can never disagree.
        recomputeSplit()
    }

    /// A blank segment for "Enter session manually": no photo, nothing read.
    init(manualLabel label: SegmentLabel) {
        self.label = label
        photoJPEG = nil
        distanceM = 0
        timeMs = 0
        splitMs = 0
        rate = 0
        ocrConfidence = 0
        lowConfidenceFields = []
    }

    // MARK: - Any two of distance, time and split give the third (decision 58)

    /// The time a split takes over a distance, to the tenth of a second: 1:45.0 over 2,000 m is
    /// 7:00.0.
    static func timeMs(splitMs: Int, distanceM: Int) -> Int {
        guard splitMs > 0, distanceM > 0 else { return 0 }
        return Int((Double(splitMs) * Double(distanceM) / 500 / 100).rounded()) * 100
    }

    /// The whole metres a split covers in a time: 2:00.0 for 30:00 is 7,500 m.
    static func distanceM(timeMs: Int, splitMs: Int) -> Int {
        guard timeMs > 0, splitMs > 0 else { return 0 }
        return Int((Double(timeMs) / Double(splitMs) * 500).rounded())
    }

    /// Average split (per 500 m), derived from distance and time — read-only in
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
