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

/// Maps OCR observations to the four PM5 fields by where they sit on
/// screen, not what they say — elapsed time and /500m split are both
/// M:SS.d-shaped, so text alone can't tell them apart, only position can.
///
/// The PM5's standard workout display lays these out in a fixed 2×2 grid —
/// time top-left, distance top-right, split bottom-left, rate bottom-right.
/// **This mapping is a best-effort default, not yet calibrated against real
/// photos** (none existed when this was written — see docs/ocr-samples/).
/// Expect to adjust the quadrant boundaries, or move to explicit regions
/// once real samples are in and task 09's verification runs for real.
/// Pure computation — no UI/actor state involved — so `nonisolated`
/// regardless of this module's default @MainActor isolation.
nonisolated enum MonitorParser {
    private enum Quadrant {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    static func parse(_ observations: [RecognizedTextObservation]) -> ParsedMonitorFields {
        var byQuadrant: [Quadrant: RecognizedTextObservation] = [:]

        for observation in observations {
            let quadrant = quadrant(for: observation.boundingBox)
            // The primary numeral in each quadrant is the largest text block
            // there — PM5 screens pair each big reading with small unit
            // labels/icons, which this should not prefer over the reading.
            let existingArea = byQuadrant[quadrant].map { $0.boundingBox.width * $0.boundingBox.height } ?? 0
            let newArea = observation.boundingBox.width * observation.boundingBox.height
            if newArea > existingArea {
                byQuadrant[quadrant] = observation
            }
        }

        return ParsedMonitorFields(
            elapsedTimeMs: field(byQuadrant[.topLeft], parse: parseDurationMs),
            distanceM: field(byQuadrant[.topRight], parse: parseDistanceM),
            splitMs: field(byQuadrant[.bottomLeft], parse: parseDurationMs),
            rate: field(byQuadrant[.bottomRight], parse: parseRate)
        )
    }

    /// Vision's boundingBox origin is bottom-left with y increasing upward —
    /// y > 0.5 is the *top* half of the image, the opposite of UIKit.
    private static func quadrant(for box: CGRect) -> Quadrant {
        let midX = box.midX
        let midY = box.midY
        switch (midX < 0.5, midY > 0.5) {
        case (true, true): return .topLeft
        case (false, true): return .topRight
        case (true, false): return .bottomLeft
        case (false, false): return .bottomRight
        }
    }

    private static func field<Value>(
        _ observation: RecognizedTextObservation?,
        parse: (String) -> Value?
    ) -> MonitorField<Value> {
        guard let observation, let value = parse(observation.text) else { return .empty }
        return MonitorField(value: value, confidence: Double(observation.confidence))
    }

    /// "8:33.2" (M:SS.d) or "1:04:50" (H:MM:SS) → milliseconds. Both time
    /// and split use this — position tells them apart, not format.
    private static func parseDurationMs(_ text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":")

        switch parts.count {
        case 3:
            // H:MM:SS
            guard
                let hours = Int(parts[0]),
                let minutes = Int(parts[1]),
                let seconds = Int(parts[2])
            else { return nil }
            return ((hours * 3600) + (minutes * 60) + seconds) * 1000

        case 2:
            // M:SS.d
            guard let minutes = Int(parts[0]) else { return nil }
            let secondsPart = parts[1].split(separator: ".")
            guard let seconds = Int(secondsPart[0]) else { return nil }
            let deciseconds = secondsPart.count > 1 ? Int(secondsPart[1]) ?? 0 : 0
            return (minutes * 60 + seconds) * 1000 + deciseconds * 100

        default:
            return nil
        }
    }

    /// "16,000" or "16000" → metres.
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
