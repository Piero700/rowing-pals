//
//  NotepadRules.swift
//  Rowing Pals
//

import Foundation

/// The arithmetic behind the coach notepad (decision 96), free of the network so it can be
/// tested: the reps a page has columns for, what each box shows, the order **Next** walks in, the
/// rowers' erg order, turning a typed time or metres into a split, and the limits on blocks.
nonisolated enum NotepadRules {
    /// The same limits `save_notepad` holds the server to.
    static let maxBlocks = 30
    static let maxTableColumns = 5
    /// Rows under a table's headings.
    static let maxTableRows = 50
    static let maxTextLength = 4000
    static let maxTableCellLength = 200
    static let maxTitleLength = 80
    static let maxNotesLength = 10000
    /// A split the notepad will save, as the server checks it.
    static let splitRange = 30_000...600_000
    static let rateRange = 10...70

    // MARK: - Columns

    /// One piece per rep the workout asks for, in order; a workout without pieces still has one
    /// column, with no piece behind it.
    static func reps(_ pieces: [WorkoutPiece]) -> [WorkoutPiece?] {
        let all = pieces.flatMap { piece in Array(repeating: Optional(piece), count: max(1, piece.reps)) }
        return all.isEmpty ? [nil] : all
    }

    /// The pieces the notepad goes by: the ones set in New workout, or, when none were set, the
    /// ones its title names ("4 x 500m" → 4 × 500 m), so the page has a column per rep without the
    /// coach doing anything more (user, 2026-11-05).
    static func pieces(of workout: CoachWorkout) -> [WorkoutPiece] {
        workout.pieces.isEmpty ? pieces(fromTitle: workout.title) : workout.pieces
    }

    /// The pieces a title names, each "count × what": a distance ("4 x 500m", "4×500", "3 x 2,000m",
    /// "2 x 6k") or a time ("8 x 2:00", "4 x 10'", "3 x 12 min"). Several can be joined ("2 x 2k +
    /// 4 x 500m"). Anything else — a single piece ("2k", "5000m"), a word — names none.
    static func pieces(fromTitle title: String) -> [WorkoutPiece] {
        let pattern = #"(?<![\d:])(\d{1,2})\s*[xX×]\s*(?:(\d{1,2}):(\d{2})(?![\d.])|(\d{1,3})\s*(?:'|′|’|min\b|mins\b|minutes\b)|(\d{1,2}(?:,\d{3})+|\d{3,5}|\d{1,2}(?:\.\d)?)\s*(km|k|m)?(?![\d:]))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let text = title as NSString
        return regex.matches(in: title, range: NSRange(location: 0, length: text.length)).compactMap { match in
            func group(_ index: Int) -> String? {
                let range = match.range(at: index)
                return range.location == NSNotFound ? nil : text.substring(with: range)
            }
            guard let count = group(1).flatMap(Int.init), (1...50).contains(count) else { return nil }
            if let minutes = group(2).flatMap(Int.init), let seconds = group(3).flatMap(Int.init), seconds < 60 {
                let ms = (minutes * 60 + seconds) * 1000
                return (60_000...7_200_000).contains(ms) ? WorkoutPiece(kind: .time, value: ms, reps: count) : nil
            }
            if let minutes = group(4).flatMap(Int.init) {
                let ms = minutes * 60_000
                return (60_000...7_200_000).contains(ms) ? WorkoutPiece(kind: .time, value: ms, reps: count) : nil
            }
            guard let number = group(5).flatMap({ Double($0.replacingOccurrences(of: ",", with: "")) }) else { return nil }
            let unit = group(6)?.lowercased()
            // "6k" and "2.5km" are kilometres; a bare small number ("4 x 2") is too ambiguous.
            let metres = unit == "k" || unit == "km" ? Int((number * 1000).rounded()) : Int(number)
            guard unit != nil || metres >= 100, (100...42_195).contains(metres) else { return nil }
            return WorkoutPiece(kind: .distance, value: metres, reps: count)
        }
    }

    // MARK: - Boxes

    /// One box, as the page shows it.
    enum Cell: Equatable {
        case empty
        /// From the rower's own linked post.
        case posted(splitMs: Int)
        /// What a coach typed (or scanned).
        case noted(splitMs: Int)
        case satOut
    }

    /// What a box shows: a coach's score wins over the rower's own post, on the notepad only.
    static func cell(noted: NotepadScore?, postedSplitMs: Int?) -> Cell {
        if let noted {
            if noted.satOut { return .satOut }
            if let split = noted.splitMs { return .noted(splitMs: split) }
        }
        if let postedSplitMs { return .posted(splitMs: postedSplitMs) }
        return .empty
    }

    /// One rower's rep, as Next walks the page.
    struct Spot: Equatable, Hashable {
        let rowerId: UUID
        let rep: Int
    }

    /// Where **Next** goes after `spot`: down to the next rower on the same rep, skipping anyone
    /// sat out on it (the coach walks along the ergs); after the last, the first empty box of the
    /// next rep that has one. Nil when the page is full.
    static func next(after spot: Spot, order: [UUID], repCount: Int, cell: (Spot) -> Cell) -> Spot? {
        if let position = order.firstIndex(of: spot.rowerId) {
            for rower in order[(position + 1)...] {
                let candidate = Spot(rowerId: rower, rep: spot.rep)
                if cell(candidate) != .satOut { return candidate }
            }
        }
        guard spot.rep + 1 < repCount else { return nil }
        for rep in (spot.rep + 1)..<repCount {
            for rower in order {
                let candidate = Spot(rowerId: rower, rep: rep)
                if cell(candidate) == .empty { return candidate }
            }
        }
        return nil
    }

    // MARK: - Rowers

    /// The rowers in erg order: those the coach placed, in that order, then everyone else by name.
    /// Anyone placed who isn't in the workout any more drops out.
    static func ordered(_ rowers: [(id: UUID, name: String)], savedOrder: [UUID]) -> [UUID] {
        let present = Set(rowers.map(\.id))
        var seen = Set<UUID>()
        let placed = savedOrder.filter { present.contains($0) && seen.insert($0).inserted }
        let rest = rowers
            .filter { !seen.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map(\.id)
        return placed + rest
    }

    /// `items` with the ones at `source` moved to `destination`, as a list's drag-to-reorder
    /// reports it (`destination` counts positions before the move).
    static func moved<Item>(_ items: [Item], from source: IndexSet, to destination: Int) -> [Item] {
        let valid = source.filter { items.indices.contains($0) }
        guard !valid.isEmpty else { return items }
        let moving = valid.map { items[$0] }
        var result = items
        for index in valid.sorted(by: >) { result.remove(at: index) }
        let insertAt = min(result.count, max(0, destination - valid.filter { $0 < destination }.count))
        result.insert(contentsOf: moving, at: insertAt)
        return result
    }

    /// "Ollie H." from "Ollie Hart"; a single name stays as it is.
    static func shortName(_ name: String) -> String {
        let parts = name.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count > 1, let first = parts.first, let initial = parts.last?.first else { return name }
        return "\(first) \(initial)."
    }

    // MARK: - Typing a score

    /// What the coach types off the monitor.
    enum EntryMode: Equatable {
        /// The average split, /500m.
        case split
        /// The piece's time (a distance piece).
        case time
        /// The metres rowed (a time piece).
        case metres
    }

    /// The choices for a rep: a distance piece takes the split or the time, a time piece the split
    /// or the metres, and a workout without pieces only the split.
    static func modes(for piece: WorkoutPiece?) -> [EntryMode] {
        switch piece?.kind {
        case .distance: [.split, .time]
        case .time: [.split, .metres]
        case nil: [.split]
        }
    }

    /// What was typed, ready to save: the split, plus the time or metres it came from.
    struct Entry: Equatable {
        let splitMs: Int
        let timeMs: Int?
        let distanceM: Int?
    }

    /// Turns a typed value into a score for `piece`, or nil when it can't be one. A split and a
    /// time come in as milliseconds, metres as metres. The split is rounded to the tenth, as the
    /// monitor shows it, and must be a split a rower could hold (`splitRange`).
    static func entry(_ value: Int, mode: EntryMode, piece: WorkoutPiece?) -> Entry? {
        guard value > 0 else { return nil }
        let result: Entry
        switch mode {
        case .split:
            result = Entry(splitMs: roundedToTenth(value), timeMs: nil, distanceM: nil)
        case .time:
            guard let piece, piece.kind == .distance, piece.value > 0 else { return nil }
            result = Entry(splitMs: roundedToTenth(Double(value) * 500 / Double(piece.value)), timeMs: value, distanceM: nil)
        case .metres:
            guard let piece, piece.kind == .time, piece.value > 0 else { return nil }
            result = Entry(splitMs: roundedToTenth(Double(piece.value) * 500 / Double(value)), timeMs: nil, distanceM: value)
        }
        return splitRange.contains(result.splitMs) ? result : nil
    }

    /// A typed rate, or nil when it's blank or no rate a rower rows at.
    static func rate(_ text: String) -> Int? {
        guard let value = Int(text.filter(\.isWholeNumber)), rateRange.contains(value) else { return nil }
        return value
    }

    /// Whole metres from what was typed.
    static func metres(_ text: String) -> Int? {
        guard let value = Int(text.filter(\.isWholeNumber).prefix(6)), value > 0 else { return nil }
        return value
    }

    private static func roundedToTenth(_ ms: Int) -> Int { roundedToTenth(Double(ms)) }
    private static func roundedToTenth(_ ms: Double) -> Int { Int((ms / 100).rounded()) * 100 }

    // MARK: - Joining monitor screens (NP2)

    /// The pieces read so far after adding one more screen.
    struct Joined: Equatable {
        /// Every piece, in order, each kept once.
        var rows: [MonitorRow]
        /// The pieces (counting from 1, on `rows`) that were on both screens and so kept once; nil
        /// when the screens didn't overlap.
        var overlap: ClosedRange<Int>?
        /// Which of `rows` came from this screen (indices), for highlighting them.
        var newIndices: Set<Int>
    }

    /// Adds one screen's rows to the pieces read so far. The summary row is dropped. When every row
    /// carries its number, the numbers decide. Otherwise the screens are taken in the order they
    /// were photographed, and the overlap is the longest run where the end of what's read matches
    /// the start of the new screen: each pair has to agree on all but at most one reading (a
    /// misread digit), with at least one pair agreeing on everything — a single-row overlap has to
    /// agree exactly, so one look-alike split can't fake one. Where the two readings of a row
    /// differ, the one whose numbers add up is kept.
    static func join(_ previous: [MonitorRow], _ screen: [MonitorRow]) -> Joined {
        let incoming = screen.filter { !$0.isSummary }
        guard !previous.isEmpty else {
            return Joined(rows: incoming, overlap: nil, newIndices: Set(incoming.indices))
        }
        if !incoming.isEmpty, let joined = joinedByNumber(previous, incoming) { return joined }

        let k = overlapLength(previous, incoming)
        var rows = previous
        for i in 0..<k {
            let index = previous.count - k + i
            rows[index] = better(previous[index], incoming[i])
        }
        rows += incoming.dropFirst(k)
        return Joined(
            rows: rows,
            overlap: k > 0 ? (previous.count - k + 1)...previous.count : nil,
            newIndices: Set(previous.count..<rows.count)
        )
    }

    /// Every screen joined in the order taken (`join` one after another).
    static func stitch(_ screens: [[MonitorRow]]) -> [MonitorRow] {
        screens.reduce([MonitorRow]()) { join($0, $1).rows }
    }

    /// The scores a scan fills a rower's row with: piece by piece from the intervals, one per rep
    /// of the workout (extra rows are left off), or the summary row for a one-piece workout. A row
    /// without a split is skipped.
    static func scannedScores(
        rows: [MonitorRow], summary: MonitorRow?, repCount: Int, workoutId: UUID, rowerId: UUID
    ) -> [NotepadScore] {
        let pieces = repCount == 1 ? [summary ?? rows.first].compactMap { $0 } : Array(rows.prefix(repCount))
        return pieces.enumerated().compactMap { index, row in
            guard let splitMs = row.splitMs else { return nil }
            return NotepadScore(
                workoutId: workoutId, userId: rowerId, pieceIndex: index, splitMs: splitMs,
                timeMs: row.timeMs, distanceM: row.distanceM, rate: row.rate, satOut: false, source: .scanned
            )
        }
    }

    /// When every row on both sides is numbered: one row per number, in number order.
    private static func joinedByNumber(_ previous: [MonitorRow], _ incoming: [MonitorRow]) -> Joined? {
        let old = previous.compactMap { row in row.number.map { ($0, row) } }
        let new = incoming.compactMap { row in row.number.map { ($0, row) } }
        guard old.count == previous.count, new.count == incoming.count else { return nil }

        var byNumber = Dictionary(old, uniquingKeysWith: { first, _ in first })
        let oldNumbers = Set(byNumber.keys)
        let newNumbers = Set(new.map(\.0))
        for (number, row) in new {
            byNumber[number] = byNumber[number].map { better($0, row) } ?? row
        }
        let numbers = byNumber.keys.sorted()
        let rows = numbers.compactMap { byNumber[$0] }
        let shared = numbers.indices.filter { oldNumbers.contains(numbers[$0]) && newNumbers.contains(numbers[$0]) }
        let overlap = shared.first.flatMap { first in shared.last.map { (first + 1)...($0 + 1) } }
        return Joined(rows: rows, overlap: overlap,
                      newIndices: Set(numbers.indices.filter { !oldNumbers.contains(numbers[$0]) }))
    }

    private static func overlapLength(_ previous: [MonitorRow], _ incoming: [MonitorRow]) -> Int {
        for k in stride(from: min(previous.count, incoming.count), through: 1, by: -1) {
            let pairs = Array(zip(previous.suffix(k), incoming.prefix(k)))
            let allClose = pairs.allSatisfy { pair in
                let (matching, differing) = agreement(pair.0, pair.1)
                return differing <= 1 && matching >= 2
            }
            guard allClose, pairs.contains(where: { isSameReading($0.0, $0.1) }) else { continue }
            if k == 1, !pairs.allSatisfy({ isSameReading($0.0, $0.1) }) { continue }
            return k
        }
        return 0
    }

    /// How many of the four readings two rows share, and how many they read differently (a reading
    /// missing from either side counts as neither).
    private static func agreement(_ a: MonitorRow, _ b: MonitorRow) -> (matching: Int, differing: Int) {
        let pairs = [(a.timeMs, b.timeMs), (a.distanceM, b.distanceM), (a.splitMs, b.splitMs), (a.rate, b.rate)]
        let known = pairs.compactMap { pair -> Bool? in
            guard let first = pair.0, let second = pair.1 else { return nil }
            return first == second
        }
        return (known.filter { $0 }.count, known.filter { !$0 }.count)
    }

    private static func isSameReading(_ a: MonitorRow, _ b: MonitorRow) -> Bool {
        let (matching, differing) = agreement(a, b)
        return differing == 0 && matching >= 3
    }

    /// The reading to keep of a row seen on two screens: the one whose numbers add up, else the
    /// first; any reading it's missing is taken from the other.
    private static func better(_ first: MonitorRow, _ second: MonitorRow) -> MonitorRow {
        let secondWins = second.addsUp && !first.addsUp
        var kept = secondWins ? second : first
        let other = secondWins ? first : second
        kept.timeMs = kept.timeMs ?? other.timeMs
        kept.distanceM = kept.distanceM ?? other.distanceM
        kept.splitMs = kept.splitMs ?? other.splitMs
        kept.rate = kept.rate ?? other.rate
        kept.number = kept.number ?? other.number
        return kept
    }

    // MARK: - Blocks

    /// A new text box.
    static func newText() -> NotepadBlock { NotepadBlock(kind: .text) }

    /// A new table: three headings ready to rename, and two empty rows.
    static func newTable() -> NotepadBlock {
        NotepadBlock(kind: .table, title: "Table", cells: [["Rower", "Technique", "Next time"], ["", "", ""], ["", "", ""]])
    }

    static func canAddBlock(_ blocks: [NotepadBlock]) -> Bool { blocks.count < maxBlocks }

    /// The table with one more empty row, unless it's full.
    static func addingRow(to block: NotepadBlock) -> NotepadBlock {
        guard block.kind == .table, block.cells.count - 1 < maxTableRows else { return block }
        var copy = block
        copy.cells.append(Array(repeating: "", count: max(1, block.cells.first?.count ?? 1)))
        return copy
    }

    /// The table with one more column, headed "Column n", unless it has `maxTableColumns`.
    static func addingColumn(to block: NotepadBlock) -> NotepadBlock {
        let columns = block.cells.first?.count ?? 0
        guard block.kind == .table, columns < maxTableColumns else { return block }
        var copy = block
        if copy.cells.isEmpty { copy.cells = [[]] }
        copy.cells = copy.cells.enumerated().map { index, row in row + [index == 0 ? "Column \(columns + 1)" : ""] }
        return copy
    }

    /// A box's text, cut to what the server keeps.
    static func clipped(_ text: String, to limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) : text
    }
}
