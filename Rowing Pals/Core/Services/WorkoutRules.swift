//
//  WorkoutRules.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// The arithmetic behind set workouts (decisions 39, 49–51), free of the network so it can be
/// tested: which of a rower's linked pieces count as which rep, done / partly / not yet, each
/// rower's target split, and the wording the cards share.
nonisolated enum WorkoutRules {
    /// One piece of a linked session, as read back from `segments`.
    struct LinkedSegment: Equatable {
        let sessionDate: String
        let position: Int
        let label: SegmentLabel
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int
        let rate: Double?
        /// An interval photo's rep distance (decision 31): one segment holding several reps.
        let repDistanceM: Int?
    }

    /// One rep as rowed.
    struct RowedRep: Equatable {
        let splitMs: Int
        let rate: Double?
    }

    /// Every rep the workout asks for, in order.
    static func totalReps(_ pieces: [WorkoutPiece]) -> Int {
        pieces.reduce(0) { $0 + max(1, $1.reps) }
    }

    /// The rower's reps, one slot per rep the workout asks for (nil: not rowed). Warm-ups and
    /// cool-downs never count. Linked pieces are taken in the order they were rowed; each fills
    /// the next rep it's long enough for, and anything else (a stray short piece) is skipped. An
    /// interval photo with a rep distance counts as that many reps at its average split.
    static func rowedReps(pieces: [WorkoutPiece], segments: [LinkedSegment]) -> [RowedRep?] {
        let wanted = pieces.flatMap { piece in Array(repeating: piece, count: max(1, piece.reps)) }
        let rowed = segments
            .filter { $0.label != .warmup && $0.label != .cooldown }
            .sorted { ($0.sessionDate, $0.position) < ($1.sessionDate, $1.position) }
            .flatMap(expand)
        var result: [RowedRep?] = Array(repeating: nil, count: wanted.count)
        var next = 0
        for rep in rowed where next < wanted.count {
            if covers(rep, wanted[next]) {
                result[next] = RowedRep(splitMs: rep.splitMs, rate: rep.rate)
                next += 1
            }
        }
        return result
    }

    /// Done, partly or not yet (decision 49): partly is a linked session that didn't complete
    /// the whole workout. Without pieces, any linked session is the workout.
    static func status(pieces: [WorkoutPiece], segments: [LinkedSegment], hasLinkedSession: Bool) -> WorkoutStatus {
        guard hasLinkedSession else { return .notYet }
        guard !pieces.isEmpty else { return .done }
        let total = totalReps(pieces)
        let completed = rowedReps(pieces: pieces, segments: segments).compactMap { $0 }.count
        return completed >= total ? .done : .partly(completed: completed, total: total)
    }

    /// A segment as the reps it holds: an interval photo with a rep distance becomes that many.
    private static func expand(_ segment: LinkedSegment) -> [LinkedSegment] {
        guard let rep = segment.repDistanceM, rep > 0, segment.distanceM >= rep * 2 else { return [segment] }
        let count = segment.distanceM / rep
        let one = LinkedSegment(sessionDate: segment.sessionDate, position: segment.position, label: segment.label,
                                distanceM: rep, timeMs: segment.timeMs / count, splitMs: segment.splitMs,
                                rate: segment.rate, repDistanceM: nil)
        return Array(repeating: one, count: count)
    }

    /// Whether a rowed piece completes one rep: the distance or time, within the monitor's own
    /// rounding (the same allowance as a test: 1%, at least 5 m or 2 s).
    static func covers(_ segment: LinkedSegment, _ piece: WorkoutPiece) -> Bool {
        switch piece.kind {
        case .distance:
            return segment.distanceM >= piece.value - max(5, piece.value / 100)
        case .time:
            return segment.timeMs >= piece.value - max(2000, piece.value / 100)
        }
    }

    // MARK: - Targets

    /// The zone a workout is rowed in: its own, AN on a test day, UT2 when none was chosen.
    static func zone(of workout: CoachWorkout) -> Tier.Name {
        if workout.isTestDay { return .an }
        return workout.zone.flatMap(Tier.Name.init(rawValue:)) ?? .ut2
    }

    /// The split a rower should hold on `piece`: the coach's own if set, else the rower's from
    /// the Pace Engine — their predicted 2k split taken to this zone and distance (decision 51).
    /// Nil without either. A time piece's distance is found from the split itself.
    static func targetSplitMs(piece: WorkoutPiece, zone: Tier.Name, twoKSplitSeconds: Double?) -> Int? {
        if let split = piece.splitMs { return split }
        guard let twoK = twoKSplitSeconds, twoK > 0 else { return nil }
        let seconds: Double
        switch piece.kind {
        case .distance:
            seconds = zoneTargetSplit(twoKSplit: twoK, zone: zone, distanceM: Double(piece.value))
        case .time:
            let pieceSeconds = Double(piece.value) / 1000
            var split = twoK + Tier.named(zone).offset
            for _ in 0..<3 {
                split = zoneTargetSplit(twoKSplit: twoK, zone: zone, distanceM: pieceSeconds * 500 / split)
            }
            seconds = split
        }
        return Int((seconds * 10).rounded()) * 100
    }

    /// "−0.2" (faster) or "+0.4" (slower), seconds per 500m.
    static func deltaText(rowedMs: Int, targetMs: Int) -> String {
        let tenths = Int((Double(rowedMs - targetMs) / 100).rounded())
        let sign = tenths < 0 ? "−" : "+"
        return "\(sign)\(abs(tenths) / 10).\(abs(tenths) % 10)"
    }

    // MARK: - Wording

    /// "2,000m", or a time in minutes as rowers say it: "20:00", "60:00".
    static func valueText(_ piece: WorkoutPiece) -> String {
        switch piece.kind {
        case .distance:
            return "\(piece.value.formattedWithGrouping)m"
        case .time:
            let seconds = piece.value / 1000
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
    }

    /// The editor's row title: "2,000m × 3".
    static func pieceTitle(_ piece: WorkoutPiece) -> String {
        "\(valueText(piece)) × \(max(1, piece.reps))"
    }

    /// "Rest 5:00 · rate 26–28 · split 1:42", or nil with none of them.
    static func pieceDetail(_ piece: WorkoutPiece) -> String? {
        var parts: [String] = []
        if let rest = piece.restMs, rest > 0 { parts.append("rest \(clock(rest))") }
        if let rate = rateText(piece) { parts.append("rate \(rate)") }
        if let split = piece.splitMs { parts.append("split \(splitText(split))") }
        guard !parts.isEmpty else { return nil }
        let text = parts.joined(separator: " · ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "26–28", "26" or nil.
    static func rateText(_ piece: WorkoutPiece) -> String? {
        switch (piece.rateMin, piece.rateMax) {
        case let (min?, max?) where min != max: "\(min)–\(max)"
        case let (min?, _): "\(min)"
        case let (nil, max?): "\(max)"
        default: nil
        }
    }

    /// The workout's rate band, from its first piece with one.
    static func rateText(_ pieces: [WorkoutPiece]) -> String? {
        pieces.lazy.compactMap { rateText($0) }.first
    }

    /// The workout's rest, from its first piece with one: "5:00".
    static func restText(_ pieces: [WorkoutPiece]) -> String? {
        pieces.lazy.compactMap { $0.restMs }.first { $0 > 0 }.map(clock)
    }

    /// The pieces in one line, as the rower's card shows them: "3 × 2,000m", "1 × 60:00".
    static func piecesSummary(_ pieces: [WorkoutPiece]) -> String? {
        guard !pieces.isEmpty else { return nil }
        return pieces.map { "\(max(1, $0.reps)) × \(valueText($0))" }.joined(separator: " + ")
    }

    /// "1:42.0", or "2:05" for a whole second.
    static func splitText(_ ms: Int) -> String {
        let tenths = Int((Double(ms) / 100).rounded())
        let minutes = tenths / 600
        let seconds = (tenths % 600) / 10
        let tenth = tenths % 10
        return tenth == 0
            ? String(format: "%d:%02d", minutes, seconds)
            : String(format: "%d:%02d.%d", minutes, seconds, tenth)
    }

    /// "1:42.0" — always to the tenth, for comparing rowed splits.
    static func splitTenthsText(_ ms: Int) -> String {
        let tenths = Int((Double(ms) / 100).rounded())
        return String(format: "%d:%02d.%d", tenths / 600, (tenths % 600) / 10, tenths % 10)
    }

    /// "5:00", "1:00:00".
    static func clock(_ ms: Int) -> String {
        let total = ms / 1000
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Days

    /// A "yyyy-MM-dd" day as a date in `calendar`.
    static func day(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// `date` as "yyyy-MM-dd" in `calendar` — the rower's own calendar day.
    static func dayText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// "Mon 6 Oct · 06:30", or "Sat 11 Oct" with no set time.
    static func whenText(_ workout: CoachWorkout, calendar: Calendar) -> String {
        guard let date = day(workout.workoutDate, calendar: calendar) else { return workout.workoutDate }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEE d MMM"
        let dayPart = formatter.string(from: date)
        guard let time = workout.startTime?.prefix(5) else { return dayPart }
        return "\(dayPart) · \(time)"
    }

    enum Section: Equatable {
        case today, upcoming, past
    }

    static func section(_ workout: CoachWorkout, today: String) -> Section {
        if workout.workoutDate == today { return .today }
        return workout.workoutDate > today ? .upcoming : .past
    }
}
