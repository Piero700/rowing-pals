//
//  BoatSeat.swift
//  Rowing Pals
//

import Foundation

/// Who sits where in a boat: seat 1 is bow, the highest is stroke, 0 is the cox.
nonisolated struct BoatSeat: Codable, Equatable, Hashable {
    let seat: Int
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case seat
        case userId = "user_id"
    }
}
