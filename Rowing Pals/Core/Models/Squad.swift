//
//  Squad.swift
//  Rowing Pals
//

import Foundation

/// A group of rowers inside a club, made by its coaches, owner or co-owners (decision 39): used
/// to filter Coaching and, from Phase 2, to say who a workout or practice is for. A rower can be
/// in several squads. Mirrors `squads` plus its `squad_members`.
nonisolated struct Squad: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var memberIds: Set<UUID>
}
