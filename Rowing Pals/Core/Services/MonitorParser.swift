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
    /// An interval workout's rep distance, from the screen's title ("8x500m/1:00r" → 500).
    /// Nil for a continuous piece or a timed-rep workout ("8x2:00/1:00r"). Decision 31.
    var repDistanceM: Int? = nil
    /// A continuous piece's split rows under the summary (a 2k's four 500m splits), each /500m;
    /// nil for an interval workout or when any row's split didn't read. Kept on the posted segment
    /// for the coach's test notepad (NP3).
    var splitRowsMs: [Int]? = nil
    /// The title names an interval workout: a rep count ("3x12:00", "8x500m") or a rest
    /// ("/3:00r", as on "v3000m/3:00r"). Its rows are reps, not one piece's splits.
    var isIntervalWorkout = false

    /// Whether all four fields extracted successfully — the task 09
    /// pass/fail bar is "all four fields correctly", not partial credit.
    var hasAllFields: Bool {
        elapsedTimeMs.value != nil && distanceM.value != nil && splitMs.value != nil && rate.value != nil
    }

    /// Whether this photo shows an erg monitor at all — decides, without
    /// asking, if an added photo becomes a piece or an environment photo
    /// (docs/design/v2-decisions.md #9). Two of the four readings is enough:
    /// the parser only returns values once it has found the monitor's table
    /// header, so a non-monitor photo yields none, while glare on one or two
    /// digits shouldn't demote a real monitor photo.
    var looksLikeMonitor: Bool {
        [elapsedTimeMs.value != nil, distanceM.value != nil, splitMs.value != nil, rate.value != nil]
            .filter { $0 }.count >= 2
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
/// When the summary row doesn't read as two of each shape (a dim screen
/// loses the colon from "5:21.7"), the row is read field by field against
/// column positions taken from a clean interval row below it, so the fields
/// that did read survive. See `readByColumn`.
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
        let tableRows = Array(rows[(headerIndex + 1)...])
        guard let summaryIndex = tableRows.firstIndex(where: { candidates(in: $0).count >= 4 }) else {
            return allEmpty
        }

        let all = candidates(in: tableRows[summaryIndex])
        let rowsBelow = tableRows[(summaryIndex + 1)...]

        let time: MonitorField<Int>
        let distance: MonitorField<Int>
        let split: MonitorField<Int>
        let rate: MonitorField<Double>
        // Time and split are both M:SS.d-shaped — only their column
        // (left/right of each other) tells them apart. Same for meter and
        // rate, both plain digits.
        let (durations, numbers) = byShape(all)
        if durations.count == 2, numbers.count == 2 {
            time = field(durations[0], parse: parseDurationMs)
            distance = field(numbers[0], parse: parseDistanceM)
            split = field(durations[1], parse: parseDurationMs)
            rate = field(numbers[1], parse: parseRate)
        } else if let columns = columnCentres(from: rowsBelow) {
            // The summary row didn't come out as two of each shape (a colon
            // lost on a dim screen: "5:21.7" read as "5217"). Read it field by
            // field instead, keeping whatever is still readable.
            (time, distance, split, rate) = readByColumn(all, columns: columns)
        } else {
            return allEmpty
        }

        // The workout title sits above the table: "8x500m/1:00r" on an interval workout.
        let title = rows[..<headerIndex].flatMap { $0 }.map(\.text).joined(separator: " ")
        let rowNumbers = rowsBelow.flatMap { byShape(candidates(in: $0)).numbers }.compactMap { parseDistanceM($0.text) }

        return ParsedMonitorFields(
            elapsedTimeMs: time,
            distanceM: distance,
            splitMs: split,
            rate: rate,
            repDistanceM: repDistance(fromTitle: title)
                ?? repDistance(fromAmbiguousTitle: title, totalDistanceM: distance.value, rowNumbers: rowNumbers),
            isIntervalWorkout: isIntervalTitle(title)
        )
    }

    /// Every row of the results table, for the coach notepad's scan (decision 96, phase NP2): the
    /// summary row first (`isSummary`, read exactly as `parse` reads it), then each interval below
    /// it, top to bottom. A row counts when it reads as two durations and two numbers, or, on a dim
    /// screen, field by field against the columns of a clean row; anything else under the table —
    /// a rest row such as "r50", a stray word — is left out. A small whole number left of the time
    /// is the row's number. Empty when there's no table header on the photo.
    static func intervalRows(_ observations: [RecognizedTextObservation]) -> [MonitorRow] {
        let rows = clusterRows(observations)
        guard let headerIndex = rows.firstIndex(where: isHeaderRow) else { return [] }
        let tableRows = Array(rows[(headerIndex + 1)...])
        guard let summaryIndex = tableRows.firstIndex(where: { candidates(in: $0).count >= 4 }) else { return [] }

        let summary = parse(observations)
        var result = [MonitorRow(
            timeMs: summary.elapsedTimeMs.value,
            distanceM: summary.distanceM.value,
            splitMs: summary.splitMs.value,
            rate: summary.rate.value.map { Int($0) },
            isSummary: true
        )]

        let rowsBelow = tableRows[(summaryIndex + 1)...]
        let columns = columnCentres(from: rowsBelow)
        for row in rowsBelow {
            if let interval = intervalRow(candidates(in: row), columns: columns) {
                result.append(interval)
            }
        }
        return result
    }

    /// A continuous piece's split rows, from `intervalRows`: every row under the summary, in order,
    /// as /500m splits. Nil unless there are 2 to 100 of them and every one has a split, since a
    /// list with a gap would put a split against the wrong distance.
    static func splitRows(_ rows: [MonitorRow]) -> [Int]? {
        let splits = rows.filter { !$0.isSummary }.map(\.splitMs)
        guard (2...100).contains(splits.count), splits.allSatisfy({ $0 != nil }) else { return nil }
        let values = splits.compactMap { $0 }
        return values.allSatisfy { (30_000...600_000).contains($0) } ? values : nil
    }

    /// One interval row, or nil when it isn't one (a rest row, a word, too little to read).
    private static func intervalRow(_ all: [Candidate], columns: [CGFloat]?) -> MonitorRow? {
        var (durations, numbers) = byShape(all)
        // A row number sits left of the time; take it off before reading the four columns.
        var number: Int?
        var numberCandidate: Candidate?
        if numbers.count == 3, let first = numbers.first, let time = durations.first, first.x < time.x,
           first.text.allSatisfy(\.isNumber), let value = Int(first.text), (1...99).contains(value) {
            number = value
            numberCandidate = first
            numbers.removeFirst()
        }
        if durations.count == 2, numbers.count == 2 {
            let time = field(durations[0], parse: parseDurationMs)
            let split = field(durations[1], parse: parseDurationMs)
            let row = MonitorRow(
                timeMs: time.value,
                distanceM: parseDistanceM(numbers[0].text),
                splitMs: split.value,
                rate: parseRate(numbers[1].text).map { Int($0) },
                number: number
            )
            return correctedSplit(row, timeConfidence: time.confidence, splitConfidence: split.confidence)
        }
        // A dim row, or one where a reading is missing (no rate, no metres): read it column by
        // column. A time and a split are enough to keep it, since the split is what the notepad
        // shows and the coach can add the rest.
        guard let columns, all.count >= 2 else { return nil }
        let remaining = all.filter { candidate in
            guard let numberCandidate else { return true }
            return candidate.x != numberCandidate.x || candidate.text != numberCandidate.text
        }
        let (time, distance, split, rate) = readByColumn(remaining, columns: columns)
        guard split.value != nil else { return nil }
        let row = MonitorRow(timeMs: time.value, distanceM: distance.value, splitMs: split.value,
                             rate: rate.value.map { Int($0) }, number: number)
        return correctedSplit(row, timeConfidence: time.confidence, splitConfidence: split.confidence)
    }

    /// A split whose tenth was misread ("1:47.9" as "1:47.0"; seen on four sample photos, always
    /// the split, while the time beside it read right), put back from the time and metres: the
    /// monitor works the split out as time ÷ (metres ÷ 500), truncated to the tenth. Only the tenth
    /// is ever changed — the worked-out split must have the same minutes and seconds — and only
    /// when Vision wasn't surer of the split than of the time, so a misread time can't drag a right
    /// split with it. A row that already adds up is left alone.
    private static func correctedSplit(_ row: MonitorRow, timeConfidence: Double, splitConfidence: Double) -> MonitorRow {
        guard !row.addsUp, let timeMs = row.timeMs, let distanceM = row.distanceM, let splitMs = row.splitMs,
              distanceM > 0, splitConfidence <= timeConfidence
        else { return row }
        let workedOut = (timeMs * 500 / distanceM) / 100 * 100
        guard workedOut / 1000 == splitMs / 1000 else { return row }
        var corrected = row
        corrected.splitMs = workedOut
        return corrected.addsUp ? corrected : row
    }

    /// A row's colon-shaped values (time, split) and plain-digit values (meter, rate), each
    /// sorted left to right.
    private static func byShape(_ candidates: [Candidate]) -> (durations: [Candidate], numbers: [Candidate]) {
        let durations = candidates.filter { $0.text.contains(":") }.sorted { $0.x < $1.x }
        let numbers = candidates.filter { !$0.text.contains(":") && $0.text.contains { $0.isNumber } }.sorted { $0.x < $1.x }
        return (durations, numbers)
    }

    /// The x of the time, meter, split and rate columns, from the first interval row under the
    /// summary that reads cleanly as two durations and two numbers. Nil when there's none (a
    /// one-row table), and then a damaged summary row can't be placed column by column.
    private static func columnCentres(from rows: ArraySlice<[RecognizedTextObservation]>) -> [CGFloat]? {
        for row in rows {
            let (durations, numbers) = byShape(candidates(in: row))
            if durations.count == 2, numbers.count == 2 {
                return [durations[0].x, numbers[0].x, durations[1].x, numbers[1].x]
            }
        }
        return nil
    }

    /// Reads a summary row field by field: each value goes to the column it sits nearest, and a
    /// field is only kept if its value has that column's shape (a colon for time and split, plain
    /// digits for meter and rate). A time that lost its colon is recovered only if it agrees with
    /// split × distance — see `recoveredTimeMs`.
    private static func readByColumn(
        _ candidates: [Candidate],
        columns: [CGFloat]
    ) -> (MonitorField<Int>, MonitorField<Int>, MonitorField<Int>, MonitorField<Double>) {
        var byColumn: [Int: Candidate] = [:]
        for candidate in candidates {
            guard let column = columns.indices.min(by: { abs(columns[$0] - candidate.x) < abs(columns[$1] - candidate.x) })
            else { continue }
            if let existing = byColumn[column], abs(columns[column] - existing.x) <= abs(columns[column] - candidate.x) {
                continue
            }
            byColumn[column] = candidate
        }

        func shaped(_ column: Int, colon: Bool) -> Candidate? {
            guard let candidate = byColumn[column], candidate.text.contains(":") == colon else { return nil }
            return candidate
        }

        let distance = shaped(1, colon: false).map { field($0, parse: parseDistanceM) } ?? .empty
        let split = shaped(2, colon: true).map { field($0, parse: parseDurationMs) } ?? .empty
        let rate = shaped(3, colon: false).map { field($0, parse: parseRate) } ?? .empty

        var time = shaped(0, colon: true).map { field($0, parse: parseDurationMs) } ?? .empty
        if time.value == nil,
           let unshaped = shaped(0, colon: false),
           let splitMs = split.value,
           let distanceM = distance.value,
           let recovered = recoveredTimeMs(fromDigits: unshaped.text, splitMs: splitMs, distanceM: distanceM) {
            time = MonitorField(value: recovered, confidence: recoveredConfidence)
        }
        return (time, distance, split, rate)
    }

    /// Below the Review sheet's 0.5 low-confidence line, so a time rebuilt from a colon-less
    /// reading is always highlighted for the rower to check.
    static let recoveredConfidence = 0.4

    /// A summary time Vision read without its colon and decimal point ("5:21.7" as "5217"), put
    /// back together as [H]MM:SS.d and kept only if it agrees with split × distance ÷ 500.
    ///
    /// The monitor truncates the split to the tenth, so the real time is never under split ×
    /// distance ÷ 500 and at most 0.1 s per 500 m over it (true of all 16 sample photos), plus
    /// 0.1 s for the time's own tenths. That pins the minutes and seconds exactly; a misread
    /// digit falls outside the window and leaves the time empty rather than guessed.
    static func recoveredTimeMs(fromDigits text: String, splitMs: Int, distanceM: Int) -> Int? {
        let digits = text.filter { $0.isNumber }
        guard digits.count == text.filter({ !$0.isWhitespace && $0 != "." && $0 != "," }).count,
              (4...6).contains(digits.count),
              let value = Int(digits), splitMs > 0, distanceM > 0
        else { return nil }

        let tenths = value % 10
        let seconds = (value / 10) % 100
        let minutesAndHours = value / 1000
        let hours = digits.count == 6 ? minutesAndHours / 100 : 0
        let minutes = digits.count == 6 ? minutesAndHours % 100 : minutesAndHours
        guard seconds < 60, digits.count < 6 || minutes < 60 else { return nil }
        let timeMs = ((hours * 3600 + minutes * 60 + seconds) * 1000) + tenths * 100

        let predictedMs = splitMs * distanceM / 500
        let allowance = 100 * distanceM / 500 + 100
        guard (predictedMs - 100...predictedMs + allowance).contains(timeMs) else { return nil }
        return timeMs
    }

    /// Whether a title names an interval workout: "3x12:00/3:00r", "8x500m/1:00r", "v3000m/3:00r".
    /// A single piece's title is a distance or a time ("2000m", "1:00:03").
    static func isIntervalTitle(_ title: String) -> Bool {
        title.range(of: #"\d\s*[xX×]\s*:?\d|/\s*\d*:\d{2}\s*r"#, options: .regularExpression) != nil
    }

    /// The rep distance when the title's "x" was misread as a zero — the PM3's small "x" in
    /// "20x500m/:20r" comes out as "200500m/:20r". Splits the digits as count + "0" + distance and
    /// keeps a reading only if the table backs it: count × distance is the summary's total, or the
    /// distance shows up in at least two interval rows (a per-rep meter column). Exactly one reading
    /// must pass, otherwise nil.
    static func repDistance(fromAmbiguousTitle title: String, totalDistanceM: Int?, rowNumbers: [Int]) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![\d])(\d{5,7})\s*m"#) else { return nil }
        let range = NSRange(title.startIndex..., in: title)
        var readings: Set<Int> = []
        for match in regex.matches(in: title, range: range) {
            guard let digitsRange = Range(match.range(at: 1), in: title) else { continue }
            let digits = Array(title[digitsRange])
            for countLength in 1...2 where countLength + 1 < digits.count {
                let distanceDigits = digits[(countLength + 1)...]
                guard digits[countLength] == "0",
                      distanceDigits.first != "0",
                      let count = Int(String(digits[..<countLength])), count >= 2,
                      let distance = Int(String(distanceDigits)), (100...10_000).contains(distance)
                else { continue }
                let matchesTotal = totalDistanceM == count * distance
                let matchesRows = rowNumbers.filter { $0 == distance }.count >= 2
                if matchesTotal || matchesRows { readings.insert(distance) }
            }
        }
        return readings.count == 1 ? readings.first : nil
    }

    /// The rep distance of a fixed-distance interval workout, from its PM5 title: a rep
    /// count, an "x", and a distance in metres — "8x500m/1:00r", "4 x 1000m", "3×2000m".
    /// Nil for anything else, including timed reps ("8x2:00/1:00r") and single pieces ("2000m").
    static func repDistance(fromTitle title: String) -> Int? {
        let pattern = #"(?<![\d])(\d{1,2})\s*[xX×]\s*(\d{1,2},?\d{3}|\d{3,5})\s*m"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(title.startIndex..., in: title)
        guard let match = regex.firstMatch(in: title, range: range),
              let countRange = Range(match.range(at: 1), in: title),
              let distanceRange = Range(match.range(at: 2), in: title),
              let count = Int(title[countRange]), count >= 2,
              let distance = Int(title[distanceRange].replacingOccurrences(of: ",", with: "")),
              (100...10_000).contains(distance)
        else { return nil }
        return distance
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
    /// interval workout photos, or with no space at all ("1:47.221"; see
    /// `splitMergedSplitAndRate`). Each part's x is placed by where its
    /// characters sit in the observation's box, so a merged split and rate
    /// each land near their own column, not both at the box's middle.
    private static func candidates(in row: [RecognizedTextObservation]) -> [Candidate] {
        row.flatMap { observation -> [Candidate] in
            let text = observation.text
            let length = CGFloat(max(text.count, 1))
            let box = observation.boundingBox
            return text.split(separator: " ").flatMap { part -> [Candidate] in
                let start = text.distance(from: text.startIndex, to: part.startIndex)
                var offset = start
                return splitMergedSplitAndRate(String(part)).map { piece in
                    let centre = CGFloat(offset) + CGFloat(piece.count) / 2
                    offset += piece.count
                    return Candidate(text: piece, x: box.minX + box.width * centre / length, confidence: observation.confidence)
                }
            }
        }
    }

    /// "1:47.221" → ["1:47.2", "21"]: a split (always exactly one tenths
    /// digit) with the rate glued straight on, as Vision reads them when
    /// the gap between the two columns is lost. A real duration never has
    /// more than one digit after its decimal point, so this can't cut one.
    static func splitMergedSplitAndRate(_ token: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"^(\d{0,2}:\d{2}[.,]\d)r?(\d{2})$"#),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)),
              let splitRange = Range(match.range(at: 1), in: token),
              let rateRange = Range(match.range(at: 2), in: token)
        else { return [token] }
        return [String(token[splitRange]), String(token[rateRange])]
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
