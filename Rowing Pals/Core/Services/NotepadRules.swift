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
