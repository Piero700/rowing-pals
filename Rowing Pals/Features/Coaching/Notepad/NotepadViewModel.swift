//
//  NotepadViewModel.swift
//  Rowing Pals
//

import Foundation

/// One set workout's notepad (CoachNotepad, decision 96): the Scores table — every rower the
/// workout is for, in erg order, one box per rep, filled from their own posts and whatever the
/// club's coaches typed — the text boxes and tables a coach added, and Notes. Coach-only: nothing
/// here is ever read by volume, pieces, PBs or leaderboards.
@Observable
final class NotepadViewModel {
    struct Rower: Identifiable, Equatable {
        let id: UUID
        let name: String
        let shortName: String
    }

    let workoutId: UUID
    var workout: CoachWorkout?
    /// "Senior men, Senior women".
    var audienceText = ""
    /// The rowers in erg order.
    var rowers: [Rower] = []
    var reps: [WorkoutPiece?] = [nil]
    var blocks: [NotepadBlock] = []
    var notes = ""
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    /// The box being typed into, and what's typed so far.
    var selection: NotepadRules.Spot?
    var mode: NotepadRules.EntryMode = .split
    /// The split or time as `DurationTextField` shows it ("1:44.6").
    var durationText = ""
    var metresText = ""
    var rateText = ""

    /// Each rower's reps from their own linked posts (nil: not rowed).
    private var posted: [UUID: [Int?]] = [:]
    /// The coaches' scores, by rower and rep.
    private(set) var noted: [NotepadRules.Spot: NotepadScore] = [:]
    /// What the server last held, so loading or a no-op edit never saves.
    private var savedPage = Page(blocks: [], notes: "", order: [])
    private var pendingSave: Task<Void, Never>?

    private struct Page: Equatable {
        let blocks: [NotepadBlock]
        let notes: String
        let order: [UUID]
    }

    init(workoutId: UUID) {
        self.workoutId = workoutId
    }

    // MARK: - Loading

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let workoutTask = WorkoutService.workout(workoutId)
            async let audienceTask = WorkoutService.audiences(of: [workoutId])
            async let sessionsTask = WorkoutService.linkedSessions(to: [workoutId])
            async let rosterTask = CoachingService.roster()
            async let pageTask = NotepadService.notepad(for: workoutId)
            async let scoresTask = NotepadService.scores(for: workoutId)
            let (workout, audiences, sessions, roster, page, scores) =
                try await (workoutTask, audienceTask, sessionsTask, rosterTask, pageTask, scoresTask)

            self.workout = workout
            let squads = Dictionary(uniqueKeysWithValues: roster.squads.map { ($0.id, $0.name) })
            let names = Dictionary(uniqueKeysWithValues: roster.rowers.map { ($0.id, $0.displayName) })
            audienceText = WorkoutsText.audience(workout, squads: squads, names: names)
            reps = NotepadRules.reps(workout.pieces)
            let audience = audiences[workoutId] ?? []
            let inWorkout = roster.rowers.filter { audience.contains($0.id) }
            let order = NotepadRules.ordered(inWorkout.map { (id: $0.id, name: $0.displayName) }, savedOrder: page?.rowerOrder ?? [])
            let byId = Dictionary(uniqueKeysWithValues: inWorkout.map { ($0.id, $0) })
            rowers = order.compactMap { id in
                byId[id].map { Rower(id: $0.id, name: $0.displayName, shortName: NotepadRules.shortName($0.displayName)) }
            }

            posted = [:]
            for rower in inWorkout {
                let segments = sessions.filter { $0.userId == rower.id }.flatMap(\.segments)
                guard !segments.isEmpty else { continue }
                posted[rower.id] = WorkoutRules.rowedReps(pieces: workout.pieces, segments: segments).map { $0?.splitMs }
            }
            noted = Dictionary(scores.map { (NotepadRules.Spot(rowerId: $0.userId, rep: $0.pieceIndex), $0) },
                               uniquingKeysWith: { _, last in last })

            // Only replace what's on screen with the server's page when nothing is waiting to save.
            if pendingSave == nil {
                blocks = page?.blocks ?? []
                notes = page?.notes ?? ""
                savedPage = Page(blocks: blocks, notes: notes, order: order)
            }
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Boxes

    func cell(_ spot: NotepadRules.Spot) -> NotepadRules.Cell {
        let rowed = posted[spot.rowerId].flatMap { $0.indices.contains(spot.rep) ? $0[spot.rep] : nil }
        return NotepadRules.cell(noted: noted[spot], postedSplitMs: rowed)
    }

    var selectedRower: Rower? {
        selection.flatMap { spot in rowers.first { $0.id == spot.rowerId } }
    }

    var selectedPiece: WorkoutPiece? {
        guard let selection, reps.indices.contains(selection.rep) else { return nil }
        return reps[selection.rep]
    }

    var modes: [NotepadRules.EntryMode] { NotepadRules.modes(for: selectedPiece) }

    /// "Ollie Hart · piece 2".
    var selectionTitle: String {
        guard let selection, let rower = selectedRower else { return "" }
        return reps.count > 1 ? "\(rower.name) · piece \(selection.rep + 1)" : rower.name
    }

    /// The line under it: where the box's score came from.
    var selectionNote: String {
        guard let selection else { return "" }
        switch cell(selection) {
        case .empty: return "Type it off the monitor."
        case .posted(let split): return "From their own post: \(WorkoutRules.splitTenthsText(split)). Yours changes only this page."
        case .noted(let split): return "On the page: \(WorkoutRules.splitTenthsText(split)). Type to change it."
        case .satOut: return "Marked as sat out. Type a score to change it."
        }
    }

    /// Whether the selected box holds a coach's score that Clear can take off.
    var canClear: Bool {
        selection.map { noted[$0] != nil } ?? false
    }

    /// Where Next goes from the selected box, after saving what's typed.
    var nextSpot: NotepadRules.Spot? {
        guard let selection else { return nil }
        return NotepadRules.next(after: selection, order: rowers.map(\.id), repCount: reps.count) { self.cellAfterSaving($0) }
    }

    /// "Next · Dan O.", "Next · piece 2", or "Done" on the last box.
    var nextTitle: String {
        guard let selection, let next = nextSpot else { return "Done" }
        if next.rep != selection.rep { return "Next · piece \(next.rep + 1)" }
        return "Next · \(rowers.first { $0.id == next.rowerId }?.shortName ?? "")"
    }

    /// What's typed now, as a score; nil when it's blank or can't be one.
    var typedEntry: NotepadRules.Entry? {
        switch mode {
        case .split, .time:
            let entry = DurationEntry.entry(from: durationText, allowsTenths: true)
            guard let ms = DurationEntry.milliseconds(entry: entry) else { return nil }
            return NotepadRules.entry(ms, mode: mode, piece: selectedPiece)
        case .metres:
            guard let metres = NotepadRules.metres(metresText) else { return nil }
            return NotepadRules.entry(metres, mode: .metres, piece: selectedPiece)
        }
    }

    var hasTyped: Bool {
        switch mode {
        case .split, .time: !durationText.isEmpty
        case .metres: !metresText.isEmpty
        }
    }

    /// "= 1:44.6 /500m" under a typed time or metres, or what's wrong with it.
    var typedHint: String {
        guard hasTyped else {
            switch mode {
            case .split: return "Average split /500m"
            case .time: return "Time for the piece"
            case .metres: return "Metres rowed"
            }
        }
        guard let entry = typedEntry else { return "That isn’t a split a rower could hold." }
        return mode == .split ? "Split /500m" : "= \(WorkoutRules.splitTenthsText(entry.splitMs)) /500m"
    }

    func select(_ spot: NotepadRules.Spot) {
        selection = spot
        clearTyping()
        if !modes.contains(mode) { mode = .split }
    }

    func closeEntry() {
        selection = nil
        clearTyping()
    }

    private func clearTyping() {
        durationText = ""
        metresText = ""
        rateText = ""
    }

    /// Saves what's typed (if anything) and moves on.
    @MainActor
    func next() async {
        guard let selection else { return }
        let target = nextSpot
        if hasTyped {
            guard let entry = typedEntry else {
                errorMessage = "Type a split between 0:30.0 and 10:00.0."
                return
            }
            await save(NotepadScore(
                workoutId: workoutId, userId: selection.rowerId, pieceIndex: selection.rep,
                splitMs: entry.splitMs, timeMs: entry.timeMs, distanceM: entry.distanceM,
                rate: NotepadRules.rate(rateText), satOut: false, source: .typed
            ))
        }
        moveTo(target)
    }

    @MainActor
    func markSatOut() async {
        guard let selection else { return }
        let score = NotepadScore(workoutId: workoutId, userId: selection.rowerId, pieceIndex: selection.rep,
                                 splitMs: nil, satOut: true)
        clearTyping()
        let target = nextSpot
        await save(score)
        moveTo(target)
    }

    /// Takes the coach's score off the selected box.
    @MainActor
    func clearScore() async {
        guard let selection, let previous = noted[selection] else { return }
        noted[selection] = nil
        clearTyping()
        do {
            try await NotepadService.deleteScore(workoutId: workoutId, userId: selection.rowerId, pieceIndex: selection.rep)
            errorMessage = nil
        } catch {
            noted[selection] = previous
            errorMessage = error.localizedDescription
        }
    }

    /// Shows the score at once and saves it; puts the old one back if the save fails.
    @MainActor
    private func save(_ score: NotepadScore) async {
        let spot = NotepadRules.Spot(rowerId: score.userId, rep: score.pieceIndex)
        let previous = noted[spot]
        noted[spot] = score
        do {
            try await NotepadService.saveScore(score)
            errorMessage = nil
        } catch {
            noted[spot] = previous
            errorMessage = error.localizedDescription
        }
    }

    private func moveTo(_ spot: NotepadRules.Spot?) {
        clearTyping()
        selection = spot
        if !modes.contains(mode) { mode = .split }
    }

    /// The page as Next will see it once what's typed is saved.
    private func cellAfterSaving(_ spot: NotepadRules.Spot) -> NotepadRules.Cell {
        if spot == selection, let entry = typedEntry { return .noted(splitMs: entry.splitMs) }
        return cell(spot)
    }

    // MARK: - Erg order

    func moveRowers(from source: IndexSet, to destination: Int) {
        rowers = NotepadRules.moved(rowers, from: source, to: destination)
        pageChanged()
    }

    // MARK: - Blocks and Notes

    var canAddBlock: Bool { NotepadRules.canAddBlock(blocks) }

    func addText() {
        guard canAddBlock else { return }
        blocks.append(NotepadRules.newText())
        pageChanged()
    }

    func addTable() {
        guard canAddBlock else { return }
        blocks.append(NotepadRules.newTable())
        pageChanged()
    }

    func remove(_ blockId: UUID) {
        blocks.removeAll { $0.id == blockId }
        pageChanged()
    }

    func addRow(to blockId: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        blocks[index] = NotepadRules.addingRow(to: blocks[index])
        pageChanged()
    }

    func addColumn(to blockId: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == blockId }) else { return }
        blocks[index] = NotepadRules.addingColumn(to: blocks[index])
        pageChanged()
    }

    /// Called after any edit to the blocks, Notes or erg order: saves a moment after typing stops.
    func pageChanged() {
        let page = currentPage
        guard page != savedPage else { return }
        pendingSave?.cancel()
        pendingSave = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await self?.savePage()
        }
    }

    /// Saves now whatever is waiting (leaving the screen).
    @MainActor
    func saveNow() async {
        guard currentPage != savedPage else { return }
        pendingSave?.cancel()
        await savePage()
    }

    private var currentPage: Page {
        let clippedBlocks = blocks.map { block -> NotepadBlock in
            var copy = block
            copy.text = NotepadRules.clipped(block.text, to: NotepadRules.maxTextLength)
            copy.title = NotepadRules.clipped(block.title, to: NotepadRules.maxTitleLength)
            copy.cells = block.cells.map { $0.map { NotepadRules.clipped($0, to: NotepadRules.maxTableCellLength) } }
            return copy
        }
        return Page(blocks: clippedBlocks, notes: NotepadRules.clipped(notes, to: NotepadRules.maxNotesLength),
                    order: rowers.map(\.id))
    }

    @MainActor
    private func savePage() async {
        let page = currentPage
        defer { pendingSave = nil }
        do {
            try await NotepadService.savePage(workoutId: workoutId, blocks: page.blocks, notes: page.notes, rowerOrder: page.order)
            savedPage = page
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
