//
//  Formatting.swift
//  PaceEngine
//
//  Port of `format_seconds` in pace_engine.py.
//

import Foundation

/// Renders seconds as `m:ss.s`, or `h:mm:ss.s` past the hour. Nil for nil or non-finite.
///
/// Quantises to 0.1 s BEFORE decomposing. Decomposing first and rounding the seconds field
/// last renders 419.96 s as "6:60.0" — the carry never reaches the minutes field.
public func formatSeconds(_ seconds: Double?) -> String? {
    guard let seconds, seconds.isFinite else { return nil }
    let sign = seconds < 0 ? "-" : ""
    var remaining = Py.round(abs(seconds), 1)
    let hours = Int(Py.floorDiv(remaining, 3600))
    remaining -= Double(hours) * 3600
    let minutes = Int(Py.floorDiv(remaining, 60))
    remaining -= Double(minutes) * 60
    if hours != 0 {
        return "\(sign)\(hours):\(String(format: "%02d", minutes)):\(String(format: "%04.1f", remaining))"
    }
    return "\(sign)\(minutes):\(String(format: "%04.1f", remaining))"
}
