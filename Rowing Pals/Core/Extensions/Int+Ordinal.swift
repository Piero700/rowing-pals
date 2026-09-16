//
//  Int+Ordinal.swift
//  Rowing Pals
//

import Foundation

extension Int {
    /// "1st", "2nd", "3rd", "4th"... for the post-detail gold result
    /// banner's rank text ("3rd overall, 1st novice women").
    var formattedOrdinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
