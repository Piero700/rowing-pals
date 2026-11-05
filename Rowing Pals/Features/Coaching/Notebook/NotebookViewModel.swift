//
//  NotebookViewModel.swift
//  Rowing Pals
//

import Foundation
import PaceEngine

/// The coach's Notebook (CoachNotebook, decision 96, NP4): one page per past workout that has a
/// notepad or any scores, oldest first and opening on the newest, filtered by squad; and one rower's
/// line across them (CoachNotebookRower), which also takes in today's workout.
@Observable
final class NotebookViewModel {
    /// The past pages, oldest first, for the squad picked.
    private(set) var pages: [NotebookRules.Page] = []
    /// Today's workouts, for a rower's line ("still being written").
    private(set) var todayPages: [NotebookRules.Page] = []
    private(set) var squads: [Squad] = []
    /// Nil: every squad.
    var squadId: UUID? {
        didSet { if squadId != oldValue { rebuild(keepingNewest: true) } }
    }
    /// The page showing.
    var index = 0
    /// Splits, or each one against the rower's target.
    var showsTarget = false
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    private var sources: [NotebookRules.Source] = []
    private var todaySources: [NotebookRules.Source] = []
    private var rowers: [NotebookRules.Rower] = []
    private(set) var fullNames: [UUID: String] = [:]
    private var predictions: [UUID: Double] = [:]

    var page: NotebookRules.Page? { pages.indices.contains(index) ? pages[index] : nil }
    var squadName: String { squads.first { $0.id == squadId }?.name ?? "All squads" }

    /// "Page 4 of 4".
    var pageLabel: String { "Page \(index + 1) of \(pages.count)" }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let today = WorkoutRules.dayText(Date(), calendar: .current)
            let workouts = try await WorkoutService.clubWorkouts()
                .filter { WorkoutRules.section($0, today: today) != .upcoming }
            let ids = workouts.map(\.id)
            async let audiencesTask = WorkoutService.audiences(of: ids)
            async let sessionsTask = WorkoutService.linkedSessions(to: ids)
            async let rosterTask = CoachingService.roster()
            async let notepadsTask = NotepadService.notepads(for: ids)
            async let scoresTask = NotepadService.scores(for: ids)
            let (audiences, sessions, roster, notepads, scores) =
                try await (audiencesTask, sessionsTask, rosterTask, notepadsTask, scoresTask)

            squads = roster.squads.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            rowers = roster.rowers.map { NotebookRules.Rower(id: $0.id, name: NotepadRules.shortName($0.displayName)) }
            fullNames = Dictionary(uniqueKeysWithValues: roster.rowers.map { ($0.id, $0.displayName) })
            predictions = Dictionary(uniqueKeysWithValues: roster.rowers.compactMap { rower in
                rower.prediction?.predictedSplitSeconds.map { (rower.id, $0) }
            })
            let pageById = Dictionary(notepads.map { ($0.workoutId, $0) }, uniquingKeysWith: { first, _ in first })
            let all = workouts.map { workout in
                NotebookRules.Source(
                    workout: workout,
                    pieces: NotepadRules.pieces(of: workout),
                    audience: audiences[workout.id] ?? [],
                    sessions: sessions.filter { $0.workoutId == workout.id },
                    notepad: pageById[workout.id],
                    scores: scores.filter { $0.workoutId == workout.id }
                )
            }
            func byDate(_ a: NotebookRules.Source, _ b: NotebookRules.Source) -> Bool {
                (a.workout.workoutDate, a.workout.startTime ?? "") < (b.workout.workoutDate, b.workout.startTime ?? "")
            }
            sources = all.filter { WorkoutRules.section($0.workout, today: today) == .past && NotebookRules.hasPage($0) }
                .sorted(by: byDate)
            todaySources = all.filter { WorkoutRules.section($0.workout, today: today) == .today }.sorted(by: byDate)
            rebuild(keepingNewest: !hasLoaded)
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Builds the pages for the squad picked. A squad's pages are the workouts any of its rowers
    /// were in, showing only them.
    private func rebuild(keepingNewest: Bool) {
        let squad = squads.first { $0.id == squadId }?.memberIds
        let shownId = page?.id
        func make(_ source: NotebookRules.Source) -> NotebookRules.Page? {
            if let squad, source.audience.isDisjoint(with: squad) { return nil }
            let zone = WorkoutRules.zone(of: source.workout)
            return NotebookRules.page(source, rowers: rowers, squad: squad) { [predictions] rowerId, piece in
                WorkoutRules.targetSplitMs(piece: piece, zone: zone, twoKSplitSeconds: predictions[rowerId])
            }
        }
        pages = sources.compactMap(make)
        todayPages = todaySources.compactMap(make)
        if keepingNewest {
            index = max(0, pages.count - 1)
        } else if let shownId, let same = pages.firstIndex(where: { $0.id == shownId }) {
            index = same
        } else {
            index = min(index, max(0, pages.count - 1))
        }
    }

    func turn(by step: Int) {
        guard !pages.isEmpty else { return }
        index = min(max(0, index + step), pages.count - 1)
    }

    // MARK: - One rower (CoachNotebookRower)

    func lines(for rowerId: UUID) -> [NotebookRules.Line] {
        NotebookRules.lines(for: rowerId, pages: pages + todayPages, today: Set(todayPages.map(\.id)))
    }

    /// The squads a rower is in, for the line under their name.
    func squadNames(of rowerId: UUID) -> String {
        let names = squads.filter { $0.memberIds.contains(rowerId) }.map(\.name)
        return names.isEmpty ? "No squad" : names.joined(separator: ", ")
    }
}
