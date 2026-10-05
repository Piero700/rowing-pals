//
//  PerfLog.swift
//  Rowing Pals
//

import Foundation
import os

/// How long each screen takes to load, written to the system log under the "perf" category so
/// a change can be measured before and after (Console app, or `log show --predicate
/// 'category == "perf"'`). Costs nothing a user would notice.
enum PerfLog {
    private static let logger = Logger(subsystem: "rowingpals", category: "perf")

    static func start() -> ContinuousClock.Instant { .now }

    static func done(_ screen: String, since start: ContinuousClock.Instant) {
        let ms = Int(((ContinuousClock.now - start) / .milliseconds(1)).rounded())
        logger.notice("\(screen, privacy: .public) loaded in \(ms) ms")
    }
}
