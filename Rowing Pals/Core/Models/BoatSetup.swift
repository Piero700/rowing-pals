//
//  BoatSetup.swift
//  Rowing Pals
//

import Foundation

/// How a boat is rigged (decisions 67, 74): its type, its rigging and, for custom rigging, the side
/// of every seat from bow to stroke ("S" stroke side, "B" bow side: a bucket four is "SBBS").
nonisolated struct BoatSetup: Equatable, Hashable, Sendable {
    var type: BoatType
    var rigging: Rigging
    /// Only for custom rigging; one letter a seat, bow first.
    var sides: String?

    init(type: BoatType, rigging: Rigging, sides: String? = nil) {
        self.type = type
        self.rigging = rigging
        self.sides = rigging == .custom ? sides : nil
    }
}
