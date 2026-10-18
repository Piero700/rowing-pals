//
//  WrappedViewModel.swift
//  Rowing Pals
//

import Foundation

/// Season Wrapped (decision 92): the club's terms to choose from (or the rower's own dates), the
/// chosen season worked out, and the rower's name for the pages.
@MainActor
@Observable
final class WrappedViewModel {
    private let initialTermId: UUID?

    private(set) var periods: [WrappedPeriod] = []
    private(set) var period: WrappedPeriod?
    private(set) var wrapped: SeasonWrapped?
    private(set) var name = ""
    private(set) var isLoading = false
    var errorMessage: String?

    /// The rower's own dates (the last 30 days to start with).
    var customStart = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    var customEnd = Calendar.current.startOfDay(for: Date())

    init(termId: UUID?) {
        initialTermId = termId
    }

    private var today: String { ChallengeRules.day(Date(), calendar: .current) }

    var isSoFar: Bool { period.map { WrappedRules.isSoFar($0, today: today) } ?? false }

    func load() async {
        name = (try? await ViewerContext.shared.current().displayName) ?? ""
        periods = await WrappedService.periods()
        await choose(startingPeriod())
    }

    /// The term it was opened for, else the term going on now (or the latest), else the last 30 days.
    private func startingPeriod() -> WrappedPeriod {
        if let initialTermId, let term = periods.first(where: { $0.termId == initialTermId }) { return term }
        if let current = WrappedRules.defaultPeriod(periods, today: today) { return current }
        return WrappedRules.custom(from: customStart, to: customEnd, calendar: .current)
    }

    func choose(_ chosen: WrappedPeriod) async {
        period = chosen
        isLoading = true
        defer { isLoading = false }
        do {
            wrapped = try await WrappedService.wrapped(for: chosen)
            errorMessage = nil
        } catch {
            wrapped = nil
            errorMessage = "Couldn’t work out this season. \(error.localizedDescription)"
        }
    }

    func useCustomDates() async {
        await choose(WrappedRules.custom(from: customStart, to: customEnd, calendar: .current))
    }
}
