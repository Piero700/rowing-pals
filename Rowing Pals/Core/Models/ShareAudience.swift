//
//  ShareAudience.swift
//  Rowing Pals
//

import Foundation

/// Who a shared week card is for (decision 110): the whole club, or one squad.
nonisolated enum ShareAudience: Equatable, Hashable {
    case club
    case squad(UUID)
}
