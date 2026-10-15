//
//  BestRow.swift
//  Rowing Pals
//

import Foundation

/// One best as it's typed on "Your bests" (decision 64): the 2k and 5k rows have their distance
/// fixed; any other is a distance and a time ("750m in 2:20"), or a time and the metres covered
/// ("20 minutes, 5,400m"). Texts hold what the fields show.
struct BestRow: Identifiable, Equatable {
    enum Kind: Equatable {
        case distance, time
    }

    let id: UUID
    var kind: Kind
    /// 2000 or 5000 for the two main rows; nil for one the rower added.
    var fixedDistanceM: Int?
    /// The distance (a distance best you added) or the metres covered (a time best).
    var metresText: String
    /// The time taken (a distance best) or how long it lasted (a time best).
    var timeText: String

    init(id: UUID = UUID(), kind: Kind = .distance, fixedDistanceM: Int? = nil, metresText: String = "", timeText: String = "") {
        self.id = id
        self.kind = kind
        self.fixedDistanceM = fixedDistanceM
        self.metresText = metresText
        self.timeText = timeText
    }

    var isEmpty: Bool {
        DurationEntry.digits(from: timeText).isEmpty && (fixedDistanceM != nil || metresText.isEmpty)
    }

    var distanceM: Int? {
        fixedDistanceM ?? Int(metresText.filter(\.isWholeNumber))
    }

    var timeMs: Int? {
        DurationEntry.milliseconds(entry: DurationEntry.entry(from: timeText, allowsTenths: kind == .distance))
    }

    /// The best, once it's a believable one: 100 m to 100 km, 10 s to 10 h, a split from 1:00 to
    /// 5:00 per 500m. Nil while empty or not yet believable.
    var parsed: (distanceM: Int, timeMs: Int)? {
        guard let distance = distanceM, (100...100_000).contains(distance),
              let time = timeMs, (10_000...36_000_000).contains(time) else { return nil }
        let split = Double(time) / (Double(distance) / 500)
        guard (60_000...300_000).contains(split) else { return nil }
        return (distance, time)
    }

    private var hasTime: Bool { !DurationEntry.digits(from: timeText).isEmpty }
    private var hasMetres: Bool { fixedDistanceM != nil || !metresText.isEmpty }

    /// One half typed, the other still to come: not wrong yet, but not saved either. The 2k and
    /// 5k rows only take a time, so a blank one is simply left out.
    var isIncomplete: Bool { fixedDistanceM == nil && hasTime != hasMetres }

    /// Both halves typed, and they aren't a believable best.
    var isInvalid: Bool { hasTime && hasMetres && parsed == nil }

    /// What's still to type, while it's half done.
    var missingHint: String? {
        guard isIncomplete else { return nil }
        switch kind {
        case .distance: return hasTime ? "Add the distance too." : "Add the time too."
        case .time: return hasTime ? "Add the metres covered too." : "Add how long it lasted too."
        }
    }

    /// Holds Save back: half-typed or unbelievable.
    var blocksSaving: Bool { isIncomplete || isInvalid }

    /// "2k", "750m", "20 min".
    var title: String {
        if let fixed = fixedDistanceM { return fixed % 1000 == 0 ? "\(fixed / 1000)k" : "\(fixed)m" }
        switch kind {
        case .distance:
            return distanceM.map { "\($0.formattedWithGrouping)m" } ?? "Distance"
        case .time:
            guard let ms = timeMs else { return "Time" }
            let seconds = ms / 1000
            return seconds % 60 == 0 ? "\(seconds / 60) min" : DurationEntry.text(digits: DurationEntry.digits(milliseconds: ms))
        }
    }

    /// The rows for saved bests: the 2k and 5k first (blank if not given), then the rest.
    static func rows(from bests: [DeclaredBest]) -> [BestRow] {
        func shown(_ ms: Int) -> String {
            DurationEntry.text(entry: DurationEntry.entry(milliseconds: ms))
        }
        var rows = [2000, 5000].map { metres in
            let best = bests.first { $0.distanceM == metres }
            return BestRow(fixedDistanceM: metres, timeText: best.map { shown($0.timeMs) } ?? "")
        }
        for best in bests where best.distanceM != 2000 && best.distanceM != 5000 {
            rows.append(BestRow(kind: .distance, metresText: String(best.distanceM), timeText: shown(best.timeMs)))
        }
        return rows
    }
}
