//
//  StandardTest+Titles.swift
//  Rowing Pals
//

import Foundation

/// How v3 names a test on screen (Profile, PB history, All personal bests).
extension StandardTest {
    /// Tile and header label: "2K", "500M", "30 MIN".
    var shortTitle: String {
        switch target {
        case .distance: label.uppercased()
        case .duration(let ms): "\(ms / 60_000) MIN"
        }
    }

    /// Another rower's PB tiles (v3 §08): "2,000 METRES", "30 MINUTES".
    var longTitle: String {
        switch target {
        case .distance(let metres): "\(metres.formattedWithGrouping) METRES"
        case .duration(let ms): "\(ms / 60_000) MINUTES"
        }
    }
}
