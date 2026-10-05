//
//  PythonParity.swift
//  PaceEngine
//
//  Small pieces of Python behaviour the port depends on, kept in one place so every
//  divergence between the two languages is visible. Each one silently changes results if
//  replaced with the "obvious" Swift equivalent.
//

import Foundation

enum Py {
    /// Python's `round(x, digits)`: the exact binary value correctly rounded, ties to even.
    /// `(x * 100).rounded() / 100` is NOT equivalent — the multiplication adds its own error
    /// and `.rounded()` ties away from zero.
    static func round(_ x: Double, _ digits: Int) -> Double {
        guard x.isFinite else { return x }
        return Double(String(format: "%.\(digits)f", x)) ?? x
    }

    /// Python's float floor division `a // b` (CPython `float_floor_div`).
    static func floorDiv(_ a: Double, _ b: Double) -> Double {
        var mod = fmod(a, b)
        var div = (a - mod) / b
        if mod != 0 {
            if (b < 0) != (mod < 0) {
                mod += b
                div -= 1.0
            }
        }
        if div != 0 {
            var floorDiv = div.rounded(.down)
            if div - floorDiv > 0.5 {
                floorDiv += 1.0
            }
            return floorDiv
        }
        return copysign(0.0, a / b)
    }

    /// Python's built-in `sum()` of floats as the golden vectors were generated (Python 3.9):
    /// plain left-to-right addition, in the order given. (Python 3.12+ switched to
    /// compensated summation; the vectors were confirmed byte-identical under 3.9.)
    static func sum<S: Sequence>(_ values: S) -> Double where S.Element == Double {
        var total = 0.0
        for value in values {
            total += value
        }
        return total
    }

    /// Python's two-argument `min(a, b)`: the first argument on a tie.
    static func min(_ a: Double, _ b: Double) -> Double { b < a ? b : a }

    /// Python's two-argument `max(a, b)`: the first argument on a tie. (Swift's `max`
    /// returns the second, which differs for -0.0 / 0.0.)
    static func max(_ a: Double, _ b: Double) -> Double { b > a ? b : a }

    /// Python's `min(items, key=...)`: the FIRST element with the smallest key.
    static func firstMin<T>(_ items: [T], by areInIncreasingOrder: (T, T) -> Bool) -> T? {
        var best: T?
        for item in items {
            if let current = best {
                if areInIncreasingOrder(item, current) { best = item }
            } else {
                best = item
            }
        }
        return best
    }

    /// Python's `max(items, key=...)`: the FIRST element with the largest key. Swift's
    /// `max(by:)` returns the LAST of equal maxima, so it must not be used for this.
    static func firstMax<T>(_ items: [T], by areInIncreasingOrder: (T, T) -> Bool) -> T? {
        var best: T?
        for item in items {
            if let current = best {
                if areInIncreasingOrder(current, item) { best = item }
            } else {
                best = item
            }
        }
        return best
    }

    /// Python's `sorted()`, which is stable. Swift's `sorted(by:)` is not guaranteed to be.
    static func stableSorted<T>(_ items: [T], by areInIncreasingOrder: (T, T) -> Bool) -> [T] {
        items.enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) { return true }
                if areInIncreasingOrder(rhs.element, lhs.element) { return false }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Python's `format(x, "g")` — C's `%g`, which Python's `g` mirrors at default precision.
    static func g(_ x: Double) -> String { String(format: "%g", x) }

    /// Python's `repr()` of the number a caller passed, for warning text.
    static func repr(_ x: Double) -> String {
        if x.isFinite, x == x.rounded(), abs(x) < 1e15 {
            return String(Int(x))
        }
        return x.isNaN ? "nan" : String(x)
    }
}

/// Calendar-day arithmetic. Python compares `date` objects; Swift must count calendar days,
/// never `TimeInterval / 86_400`, which is wrong across the March and October clock changes.
struct CalendarDays {
    let calendar: Calendar
    private let origin: Date

    init(calendar: Calendar) {
        self.calendar = calendar
        origin = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
    }

    /// A day number in this calendar — the equivalent of Python's `date.toordinal()`, up to a
    /// constant, so differences between two of them are whole calendar days.
    func number(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: origin, to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// `date.isoformat()`: "YYYY-MM-DD" in this calendar.
    func iso(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
