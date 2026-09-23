//
//  StreakCalculator.swift
//  Rowing Pals
//

import Foundation

/// Pure client-side port of `current_streak(p_user, p_today)` in
/// docs/schema.sql — that `plpgsql` function walks backward from today
/// through one user's `daily_totals` rows, counting active days and
/// absorbing up to 2 missed days per ISO week as "rest" before a 3rd miss
/// in that week breaks the run, bounded to 730 days back as a safety stop.
/// This type replicates that algorithm exactly, day-by-day, rule-by-rule.
///
/// Why this exists rather than just calling the RPC: a screen showing many
/// people at once (a feed page, a leaderboard page) would otherwise need
/// one `current_streak(...)` RPC round trip *per visible avatar* — N+1,
/// each one its own day-by-day Postgres scan. Instead, callers batch every
/// visible author's `daily_totals` into ONE `.in("user_id", values:)`
/// query (see `FeedViewModel.fetchStreaks`, `MetresLeaderboardViewModel.
/// performReload`, `TestLeaderboardViewModel.performReload`), group the
/// rows by `user_id`, and call `streak(activeDays:)` once per user against
/// that already-fetched data. `AvatarPlaceholder`'s own doc comment
/// describes the same batching approach from the UI side.
///
/// The one legitimate exception is `ProfileViewModel.fetchStreak`, which
/// still calls the real `current_streak(...)` RPC directly — it's a single
/// user (the signed-in one), not a batch, so the N+1 concern doesn't apply
/// and it remains the source of truth.
///
/// Keep this in exact lockstep with `current_streak` in docs/schema.sql —
/// letting the two drift out of sync would show a different streak number
/// on someone's feed card or leaderboard row than on their own profile.
enum StreakCalculator {
    /// - Parameters:
    ///   - activeDays: the "yyyy-MM-dd" day-strings (Postgres `date`, same
    ///     wire format as `DailyTotal.day` / `Session.sessionDate` — see
    ///     the note on `Session.sessionDate` for why a plain string rather
    ///     than `Date`, to avoid a UTC-shift bug) on which this ONE user
    ///     has a `daily_totals` row with `session_count > 0`. Not filtered
    ///     to a recent window — the walk can legitimately reach up to 730
    ///     days back, so callers should fetch each user's full history.
    ///   - today: the user's local calendar "today". Defaults to `Date()`;
    ///     overridable for tests.
    /// - Returns: the number of active days in the current streak — the
    ///   same value `current_streak`'s `active_days` column returns.
    static func streak(activeDays: Set<String>, today: Date = Date()) -> Int {
        // Same Calendar.current + firstWeekday = 2 (Monday) convention
        // already used by ProfileViewModel's longestStreak/weeklyVolumes/
        // consistencyGrid to approximate the SQL function's ISO week
        // (`to_char(d, 'IYYY-IW')`) grouping — kept consistent with that
        // existing approximation rather than introducing a second, subtly
        // different one via Calendar(identifier: .iso8601).
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        func hasSession(on date: Date) -> Bool {
            activeDays.contains(formatter.string(from: date))
        }

        let todayStart = calendar.startOfDay(for: today)
        var d = todayStart

        // "Nothing logged yet today? Start judging from yesterday" — the
        // SQL function's own comment: today never breaks a streak because
        // the day isn't over yet.
        if !hasSession(on: d) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: d) else { return 0 }
            d = yesterday
        }

        guard let boundary = calendar.date(byAdding: .day, value: -730, to: todayStart) else { return 0 }

        var activeCount = 0
        var missesByWeek: [Int: Int] = [:]

        while true {
            let weekKey = calendar.component(.yearForWeekOfYear, from: d) * 100 + calendar.component(.weekOfYear, from: d)

            if hasSession(on: d) {
                activeCount += 1
            } else {
                let misses = missesByWeek[weekKey, default: 0]
                if misses >= 2 { break } // rest allowance spent: streak ends
                missesByWeek[weekKey] = misses + 1
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: d) else { break }
            d = previous
            if d < boundary { break } // 730-day safety bound
        }

        return activeCount
    }
}
