//
//  MonitorParser.swift
//  Rowing Pals
//

import CoreGraphics
import Foundation

/// One extracted field, with a confidence — nil `value` means nothing
/// plausible was found in that field's screen region at all.
nonisolated struct MonitorField<Value> {
    let value: Value?
    /// 0...1. 0 when `value` is nil. Review sheet low-confidence styling
    /// (task 10) reads this directly.
    let confidence: Double

    static var empty: Self { .init(value: nil, confidence: 0) }
}

nonisolated struct ParsedMonitorFields {
    let elapsedTimeMs: MonitorField<Int>
    let distanceM: MonitorField<Int>
    let splitMs: MonitorField<Int>
    let rate: MonitorField<Double>

    /// Whether all four fields extracted successfully — the task 09
    /// pass/fail bar is "all four fields correctly", not partial credit.
    var hasAllFields: Bool {
        elapsedTimeMs.value != nil && distanceM.value != nil && splitMs.value != nil && rate.value != nil
    }
}

/// Maps OCR observations to the four PM5 fields using the real "View
/// Detail" log screen layout (confirmed against 16 real monitor photos in
/// docs/ocr-samples/) — NOT the live "Just Row" 2×2 grid this originally
/// assumed before real samples existed.
///
/// That screen is a table: a header row (`time  meter  /500m  s/m`), then
/// one data row per piece/interval, starting with the summary/total row
/// immediately below the header. This finds that header row, then reads
/// the summary row directly beneath it.
///
/// Column *text* is unreliable — Vision sometimes merges header words into
/// one observation, sometimes splits them, and misreads "/500m" as
/// "1500m". Column *order* is not: across every real sample, time sits
/// left of meter, which sits left of split, which sits left of rate. This
/// classifies each row's values by shape (does it contain a colon?) and
/// then by left-to-right position within its shape group, rather than by
/// matching header text to data.
///
/// Pure computation — no UI/actor state involved — so `nonisolated`
/// regardless of this module's default @MainActor isolation.
nonisolated enum MonitorParser {
    /// A single value read off the screen, with enough position info to
    /// sort it against the other values in its row.
    private struct Candidate {
        let text: String
        let x: CGFloat
        let confidence: Float
    }

    static func parse(_ observations: [RecognizedTextObservation]) -> ParsedMonitorFields {
        let rows = clusterRows(observations)

        guard let headerIndex = rows.firstIndex(where: isHeaderRow) else { return allEmpty }

        // The summary/total row is the first row below the header — not
        // just any row containing four numbers, since per-split rows
        // further down the table look identical in shape.
        guard let dataRow = rows[(headerIndex + 1)...].first(where: { candidates(in: $0).count >= 4 }) else {
            return allEmpty
        }

        let all = candidates(in: dataRow)
        // Time and split are both M:SS.d-shaped — only their column
        // (left/right of each other) tells them apart. Same for meter and
        // rate, both plain digits.
        let durations = all.filter { $0.text.contains(":") }.sorted { $0.x < $1.x }
        let numbers = all.filter { !$0.text.contains(":") && $0.text.contains { $0.isNumber } }.sorted { $0.x < $1.x }

        guard durations.count == 2, numbers.count == 2 else { return allEmpty }

        return ParsedMonitorFields(
            elapsedTimeMs: field(durations[0], parse: parseDurationMs),
            distanceM: field(numbers[0], parse: parseDistanceM),
            splitMs: field(durations[1], parse: parseDurationMs),
            rate: field(numbers[1], parse: parseRate)
        )
    }

    private static var allEmpty: ParsedMonitorFields {
        ParsedMonitorFields(elapsedTimeMs: .empty, distanceM: .empty, splitMs: .empty, rate: .empty)
    }

    /// The real header row always carries "meter" as a column label, and
    /// nothing else on the screen does — titles show a bare distance like
    /// "1500m", never the word "meter". Deliberately doesn't also require
    /// "time": on a blurry photo Vision read that word as "ume" (dropped
    /// the leading "t"), while "meter" still came through clean, so
    /// requiring both would have missed the row entirely.
    private static func isHeaderRow(_ row: [RecognizedTextObservation]) -> Bool {
        row.contains { $0.text.lowercased().contains("meter") }
    }

    /// Groups observations into visual rows by y-position. Vision gives
    /// each word its own observation with slightly different y even within
    /// one printed line (seen up to ~0.004 apart in real samples); real
    /// rows in the table are reliably >0.02 apart. 0.015 sits between them.
    private static func clusterRows(_ observations: [RecognizedTextObservation]) -> [[RecognizedTextObservation]] {
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[RecognizedTextObservation]] = []
        for observation in sorted {
            if let lastIndex = rows.indices.last,
               let anchor = rows[lastIndex].first,
               abs(anchor.boundingBox.midY - observation.boundingBox.midY) <= 0.015 {
                rows[lastIndex].append(observation)
            } else {
                rows.append([observation])
            }
        }
        return rows
    }

    /// Splits each observation on whitespace before sorting by x. Needed
    /// because Vision sometimes reads two adjacent columns as a single
    /// observation — e.g. split and rate glued together as "1:54.3 19" on
    /// interval workout photos. A tiny x offset per sub-part preserves
    /// their left-to-right order without needing real per-part geometry.
    private static func candidates(in row: [RecognizedTextObservation]) -> [Candidate] {
        row.flatMap { observation -> [Candidate] in
            observation.text.split(separator: " ").enumerated().map { index, part in
                Candidate(
                    text: String(part),
                    x: observation.boundingBox.midX + CGFloat(index) * 0.0001,
                    confidence: observation.confidence
                )
            }
        }
    }

    private static func field<Value>(_ candidate: Candidate, parse: (String) -> Value?) -> MonitorField<Value> {
        guard let value = parse(candidate.text) else { return .empty }
        return MonitorField(value: value, confidence: Double(candidate.confidence))
    }

    /// "8:33.2" (M:SS.d), "1:04:50" (H:MM:SS), or ":40.7" (SS.d with no
    /// leading minutes digit — real PM5 photos produce this under a
    /// minute). Both elapsed time and /500m split use this — position
    /// tells them apart, not format.
    ///
    /// Real photos also show "1:19,0" alongside "1:19.0" for what is
    /// unmistakably the same on-screen value (duplicate reflected rows
    /// with identical everything else) — Vision misreads the decimal
    /// point as a comma often enough that both must be accepted.
    private static func parseDurationMs(_ text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        // `omittingEmptySubsequences: false` keeps the empty component
        // before a leading colon, so ":40.7" parses as 2 parts ("", "40.7")
        // rather than collapsing to 1 and falling through to nil.
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)

        switch parts.count {
        case 3:
            guard let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
            let secondsPart = parts[2].split(separator: ".")
            guard let seconds = Int(secondsPart[0]) else { return nil }
            let deciseconds = secondsPart.count > 1 ? Int(secondsPart[1]) ?? 0 : 0
            return ((hours * 3600) + (minutes * 60) + seconds) * 1000 + deciseconds * 100

        case 2:
            let minutes: Int
            if parts[0].isEmpty {
                minutes = 0
            } else if let parsed = Int(parts[0]) {
                minutes = parsed
            } else {
                return nil
            }
            let secondsPart = parts[1].split(separator: ".")
            guard let seconds = Int(secondsPart[0]) else { return nil }
            let deciseconds = secondsPart.count > 1 ? Int(secondsPart[1]) ?? 0 : 0
            return (minutes * 60 + seconds) * 1000 + deciseconds * 100

        default:
            return nil
        }
    }

    /// "16,000" or "16000" → metres. The comma here is a thousands
    /// separator (unlike the decimal comma in duration fields above) —
    /// stripping to digits-only handles both spellings identically.
    private static func parseDistanceM(_ text: String) -> Int? {
        let digitsOnly = text.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return nil }
        return Int(digitsOnly)
    }

    /// "r19" or "19" → strokes per minute.
    private static func parseRate(_ text: String) -> Double? {
        let digitsOnly = text.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return nil }
        return Double(digitsOnly)
    }
}
