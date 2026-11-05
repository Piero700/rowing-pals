//
//  CoachNotepad.swift
//  Rowing Pals
//

import Foundation

/// A set workout's notepad page (decision 96): the blocks the coach added, its Notes, and the
/// order the coach put the rowers in. Mirrors `coach_notepads`; a workout has none until a coach
/// first changes something on its page.
nonisolated struct CoachNotepad: Decodable, Equatable {
    let workoutId: UUID
    let clubId: UUID
    let blocks: [NotepadBlock]
    let notes: String
    /// Rowers in erg order; anyone not listed follows, by name.
    let rowerOrder: [UUID]

    enum CodingKeys: String, CodingKey {
        case blocks, notes
        case workoutId = "workout_id"
        case clubId = "club_id"
        case rowerOrder = "rower_order"
    }

    init(workoutId: UUID, clubId: UUID, blocks: [NotepadBlock], notes: String, rowerOrder: [UUID]) {
        self.workoutId = workoutId
        self.clubId = clubId
        self.blocks = blocks
        self.notes = notes
        self.rowerOrder = rowerOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workoutId = try c.decode(UUID.self, forKey: .workoutId)
        clubId = try c.decode(UUID.self, forKey: .clubId)
        blocks = try c.decodeIfPresent([NotepadBlock].self, forKey: .blocks) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        rowerOrder = try c.decodeIfPresent([UUID].self, forKey: .rowerOrder) ?? []
    }
}
