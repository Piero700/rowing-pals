//
//  WrappedPage.swift
//  Rowing Pals
//

import Foundation

/// The pages of a Season Wrapped (decision 92), in order: the season, totals, streaks, PBs, club and
/// crew, and the training mix. A season with nothing rowed is one quiet page.
nonisolated enum WrappedPage: Int, CaseIterable, Identifiable {
    case season, totals, streaks, pbs, crew, mix

    var id: Int { rawValue }

    /// "Season", "PBs" — read aloud and named in the share sheet.
    var name: String {
        switch self {
        case .season: "Your season"
        case .totals: "Totals"
        case .streaks: "Streaks"
        case .pbs: "Personal bests"
        case .crew: "Club and crew"
        case .mix: "Training mix"
        }
    }

    static func pages(for wrapped: SeasonWrapped) -> [WrappedPage] {
        wrapped.isEmpty ? [.season] : allCases
    }
}
