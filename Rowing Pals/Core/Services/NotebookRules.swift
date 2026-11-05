//
//  NotebookRules.swift
//  Rowing Pals
//

import Foundation

/// The coach's Notebook (CoachNotebook, CoachNotebookRower; decision 96, NP4): one page per past
/// workout that has a notepad or any scores, each rower's pieces on it (their own post, or what a
/// coach noted, which wins), and one rower's line across the pages. Pure, so it can be tested.
nonisolated enum NotebookRules {
    /// One workout, with everything the Notebook reads about it.
    struct Source {
        let workout: CoachWorkout
        /// The pieces the page goes by (`NotepadRules.pieces(of:)`).
        let pieces: [WorkoutPiece]
        let audience: Set<UUID>
        let sessions: [WorkoutService.LinkedSession]
        let notepad: CoachNotepad?
        let scores: [NotepadScore]
    }

    /// A rower as the Notebook names them.
    struct Rower: Equatable {
        let id: UUID
        let name: String
    }

    /// Where a rower's line on a page came from.
    enum Origin: Equatable {
        /// Nothing yet.
        case none
        /// Their own post.
        case posted
        /// A coach typed or scanned at least one of their pieces.
        case noted
        /// Sat out every piece.
        case satOut
    }

    struct Row: Identifiable, Equatable {
        var id: UUID { rowerId }
        let rowerId: UUID
        let name: String
        /// One per rep: the split, or nil (not rowed, or sat out).
        let splits: [Int?]
        let satOut: [Bool]
        /// One per rep: the rower's target split, when there is one.
        let targets: [Int?]
        /// A test's result: its time (or metres for a timed test).
        let timeMs: Int?
        let metres: Int?
        let origin: Origin

        var average: Int? { Self.mean(splits) }
        /// The average of the targets for the pieces rowed.
        var averageTarget: Int? { Self.mean(zip(splits, targets).map { $0.0 == nil ? nil : $0.1 }) }
        /// The average against its target (positive: slower).
        var averageDelta: Int? {
            guard let average, let averageTarget else { return nil }
            return average - averageTarget
        }
        var isAllSatOut: Bool { !satOut.isEmpty && satOut.allSatisfy { $0 } }
        var hasSplits: Bool { splits.contains { $0 != nil } }

        static func mean(_ values: [Int?]) -> Int? {
            let known = values.compactMap { $0 }
            guard !known.isEmpty else { return nil }
            let tenths = (Double(known.reduce(0, +)) / Double(known.count) / 100).rounded()
            return Int(tenths) * 100
        }
    }

    struct Page: Identifiable, Equatable {
        var id: UUID { workout.id }
        let workout: CoachWorkout
        let reps: [WorkoutPiece?]
        let test: StandardTest?
        let rows: [Row]
        let notes: String

        var isTest: Bool { test != nil && reps.count == 1 }
        var posted: Int { rows.filter { $0.origin == .posted }.count }
        var noted: Int { rows.filter { $0.origin == .noted }.count }
        var satOut: Int { rows.filter { $0.origin == .satOut }.count }

        /// "6 posted · 4 you noted · 1 sat out" (only the parts that aren't nought).
        var sourcesText: String {
            var parts: [String] = []
            if posted > 0 { parts.append("\(posted) posted") }
            if noted > 0 { parts.append("\(noted) you noted") }
            if satOut > 0 { parts.append("\(satOut) sat out") }
            return parts.isEmpty ? "Nothing in yet" : parts.joined(separator: " · ")
        }

        /// The squad's average on each piece, and over all of them.
        var squadSplits: [Int?] { reps.indices.map { rep in Row.mean(rows.map { $0.splits[rep] }) } }
        var squadAverage: Int? { Row.mean(rows.map(\.average)) }
        /// The squad's average against target on each piece, and over all (positive: slower).
        var squadDeltas: [Int?] {
            reps.indices.map { rep in
                Row.mean(rows.map { row in
                    guard let split = row.splits[rep], let target = row.targets[rep] else { return nil }
                    return split - target
                })
            }
        }
        var squadAverageDelta: Int? { Row.mean(rows.map(\.averageDelta)) }
        var squadTime: Int? { Row.mean(rows.map(\.timeMs)) }
    }

    /// Whether a past workout gets a page: it has a notepad, a coach's score, or a rower's post.
    static func hasPage(_ source: Source) -> Bool {
        source.notepad != nil || !source.scores.isEmpty || !source.sessions.isEmpty
    }

    /// One workout's page: its rowers in erg order (only those in `squad`, when given), each with
    /// their pieces — the coach's score where there is one, else the rower's own post.
    static func page(
        _ source: Source, rowers: [Rower], squad: Set<UUID>? = nil,
        target: (UUID, WorkoutPiece) -> Int? = { _, _ in nil }
    ) -> Page {
        let reps = NotepadRules.reps(source.pieces)
        let test = NotepadRules.test(of: source.workout)
        let inPage = rowers.filter { source.audience.contains($0.id) && (squad?.contains($0.id) ?? true) }
        let order = NotepadRules.ordered(inPage.map { (id: $0.id, name: $0.name) }, savedOrder: source.notepad?.rowerOrder ?? [])
        let byId = Dictionary(uniqueKeysWithValues: inPage.map { ($0.id, $0) })
        let noted = Dictionary(source.scores.map { (NotepadRules.Spot(rowerId: $0.userId, rep: $0.pieceIndex), $0) },
                               uniquingKeysWith: { _, last in last })

        let rows: [Row] = order.compactMap { id in
            guard let rower = byId[id] else { return nil }
            let segments = source.sessions.filter { $0.userId == id }.flatMap(\.segments)
            let posted = segments.isEmpty ? [] : WorkoutRules.rowedReps(pieces: source.pieces, segments: segments)
            var splits: [Int?] = []
            var satOut: [Bool] = []
            var anyNoted = false
            var anyPosted = false
            for rep in reps.indices {
                let spot = NotepadRules.Spot(rowerId: id, rep: rep)
                let postedSplit = posted.indices.contains(rep) ? posted[rep]?.splitMs : nil
                switch NotepadRules.cell(noted: noted[spot], postedSplitMs: postedSplit) {
                case .noted(let split): splits.append(split); satOut.append(false); anyNoted = true
                case .posted(let split): splits.append(split); satOut.append(false); anyPosted = true
                case .satOut: splits.append(nil); satOut.append(true)
                case .empty: splits.append(nil); satOut.append(false)
                }
            }
            let first = NotepadRules.Spot(rowerId: id, rep: 0)
            let piece = reps.first ?? nil
            let timeMs = noted[first]?.timeMs ?? splits.first.flatMap { $0 }.flatMap { NotepadRules.time(splitMs: $0, piece: piece) }
            let metres = noted[first]?.distanceM ?? splits.first.flatMap { $0 }.flatMap { NotepadRules.metres(splitMs: $0, piece: piece) }
            let origin: Origin = anyNoted ? .noted : (anyPosted ? .posted : (satOut.allSatisfy { $0 } && !satOut.isEmpty ? .satOut : .none))
            return Row(
                rowerId: id, name: rower.name, splits: splits, satOut: satOut,
                targets: reps.map { piece in piece.flatMap { target(id, $0) } },
                timeMs: test != nil ? timeMs : nil, metres: test != nil ? metres : nil, origin: origin
            )
        }
        return Page(workout: source.workout, reps: reps, test: test, rows: rows, notes: source.notepad?.notes ?? "")
    }

    /// "+1.5", "−0.2", "±0.0": a split against its target, in seconds (positive: slower).
    static func deltaText(_ ms: Int) -> String { NotepadRules.fadeText(ms) }

    // MARK: - One rower's line (CoachNotebookRower)

    struct Line: Identifiable, Equatable {
        var id: UUID { page.id }
        let page: Page
        let row: Row
        let isToday: Bool
    }

    struct RowerSummary: Equatable {
        /// Pages they rowed on, of the pages they were in.
        let done: Int
        let of: Int
        /// Their average against target across the pages that had one (positive: slower).
        let averageDelta: Int?
        let fastestMs: Int?
    }

    /// The rower's line on every page they're in, newest first.
    static func lines(for rowerId: UUID, pages: [Page], today: Set<UUID> = []) -> [Line] {
        pages.compactMap { page in
            page.rows.first { $0.rowerId == rowerId }.map { Line(page: page, row: $0, isToday: today.contains(page.id)) }
        }
        .sorted { ($0.page.workout.workoutDate, $0.page.workout.startTime ?? "") > ($1.page.workout.workoutDate, $1.page.workout.startTime ?? "") }
    }

    /// Sessions done, average against target and fastest piece, over the past pages (today's
    /// session, still being written, isn't counted).
    static func summary(_ lines: [Line]) -> RowerSummary {
        let past = lines.filter { !$0.isToday }
        let rowed = past.filter { $0.row.hasSplits }
        return RowerSummary(
            done: rowed.count, of: past.count,
            averageDelta: Row.mean(past.map { $0.page.isTest ? nil : $0.row.averageDelta }),
            fastestMs: past.filter { !$0.page.isTest }.flatMap { $0.row.splits.compactMap { $0 } }.min()
        )
    }
}
