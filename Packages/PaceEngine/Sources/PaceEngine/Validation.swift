//
//  Validation.swift
//  PaceEngine
//
//  Port of `_to_float`, `parse_duration` (numeric path), `_normalise_rpe`, `_normalise_sex`,
//  `Athlete`, `_normalise_athlete`, `Session`, `_normalise_session` and `_dedupe_raw`.
//

import Foundation

// MARK: - Numbers

/// `_to_float`: a finite number, else nil.
func toFloat(_ value: Double?) -> Double? {
    guard let value, value.isFinite else { return nil }
    return value
}

/// `parse_duration` for a number: finite and positive, else nil.
func parseDuration(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value > 0 else { return nil }
    return value
}

/// `_normalise_rpe`: onto Borg CR10 (0–10). Values strictly between 10 and 11 are neither
/// scale and are rejected; 11–20 are Borg 6–20 and convert as (v − 6) / 1.4.
func normaliseRPE(_ value: Double?) -> Double? {
    guard var number = toFloat(value) else { return nil }
    if 10.0 < number && number < 11.0 {
        return nil
    }
    if 11.0 <= number && number <= 20.0 {
        number = (number - 6.0) / 1.4
    }
    if !(0.0 <= number && number <= 10.0) {
        return nil
    }
    return number
}

/// `_normalise_sex`: "male", "female", or nil for anything else (a legitimate answer).
func normaliseSex(_ value: String?) -> String? {
    guard let value else { return nil }
    let text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if ["m", "male", "man"].contains(text) { return "male" }
    if ["f", "female", "woman"].contains(text) { return "female" }
    return nil
}

// MARK: - Athlete

/// The parsed profile (`Athlete`). Every field optional.
struct Athlete {
    var age: Double?
    var sex: String?
    var weightKg: Double?
    /// True when the sex/gender question was answered at all, including with a value outside
    /// male/female, so that answer gets the same level of service as "male".
    var sexDeclared = false

    var isEmpty: Bool {
        age == nil && weightKg == nil && sex == nil && !sexDeclared
    }
}

/// `_normalise_athlete`. Never fails; implausible values are dropped with a warning.
func normaliseAthlete(_ raw: AthleteProfile?, warnings: inout [String]) -> Athlete {
    guard let raw else { return Athlete() }

    var age = toFloat(raw.age)
    if let value = age, !(5.0 <= value && value <= 110.0) {
        warnings.append("athlete age \(Py.g(value)) is outside 5-110; ignored")
        age = nil
    }

    var weight = toFloat(raw.weightKg)
    if let value = weight, !(25.0 <= value && value <= 250.0) {
        warnings.append("athlete weight \(Py.g(value))kg is outside 25-250; ignored")
        weight = nil
    }

    let sex = normaliseSex(raw.sex)
    let sexDeclared = raw.sex.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
    if sex == nil && sexDeclared {
        warnings.append("athlete sex not recognised as male/female; using the sex-neutral prior")
    }

    return Athlete(age: age, sex: sex, weightKg: weight, sexDeclared: sexDeclared)
}

// MARK: - Session

/// A validated, canonical session (`Session`).
struct Session {
    let id: String
    /// Calendar day number (see `CalendarDays`).
    let day: Int
    /// The original date, for `isoformat()` output.
    let date: Date
    let distanceM: Double
    let timeS: Double
    let splitS: Double
    let tag: Tier.Name
    let strokeRate: Double?
    let repDistanceM: Double?
    let effectiveDistanceM: Double
    let intervalAmbiguous: Bool
    let rateMismatch: Bool
    let rpe: Double?
    let rpeMismatch: Bool
    let bodyweightKg: Double?

    var durationMinutes: Double { timeS / 60.0 }

    var tier: Tier { Tier.named(tag) }

    /// Signed RPE distance from the tier's expected midpoint; 0.0 when RPE is absent.
    var rpeDeviation: Double {
        guard let rpe else { return 0.0 }
        return rpe - tier.rpeMid
    }
}

/// `_normalise_session`. Returns nil if unusable, with a warning naming the row.
func normaliseSession(
    _ raw: SessionInput,
    index: Int,
    day: Int,
    config: EngineConfig,
    warnings: inout [String]
) -> Session? {
    // `str(_pluck(raw, "id") or f"row-{index}")` — an empty id is falsy in Python.
    let sessionId = raw.id.isEmpty ? "row-\(index)" : raw.id
    let tag = raw.tag
    let tier = Tier.named(tag)

    guard let distance = toFloat(raw.distanceM), distance > 0 else {
        warnings.append("\(sessionId): distance must be a positive number, skipped")
        return nil
    }

    var timeS = parseDuration(raw.timeS)
    var splitS = parseDuration(raw.splitS)

    // Derive whichever of time/split is absent.
    let derivedSplit: Double? = timeS.map { ($0 / distance) * 500.0 }
    if splitS == nil && derivedSplit == nil {
        warnings.append("\(sessionId): needs at least one of time or average split, skipped")
        return nil
    }
    if splitS == nil {
        splitS = derivedSplit
    } else if let derived = derivedSplit, let stated = splitS {
        let divergence = abs(derived - stated) / derived
        if divergence > config.splitMismatchTolerance {
            // Prefer the derived value: a typed average split can silently exclude rest.
            warnings.append(
                "\(sessionId): stated split \(formatSeconds(stated) ?? "") disagrees with "
                    + "time/distance (\(formatSeconds(derived) ?? "")) by "
                    + "\(String(format: "%.0f", divergence * 100))%; using time/distance"
            )
            splitS = derived
        }
    }
    guard let split = splitS else { return nil }
    if timeS == nil {
        timeS = split * distance / 500.0
    }
    guard let time = timeS else { return nil }

    if !(0 < split && split < config.ceilingSplit * 2) {
        warnings.append("\(sessionId): implausible split \(String(format: "%.1f", split))s, skipped")
        return nil
    }

    var strokeRate = toFloat(raw.strokeRate)
    if let rate = strokeRate, !(0 < rate && rate < 60) {
        strokeRate = nil
    }
    let rateMismatch = strokeRate.map { !(tier.rateLo <= $0 && $0 <= tier.rateHi) } ?? false

    // A declared rep distance is trusted; without one, a maximal-tier session too long to be
    // one continuous effort is flagged rather than guessed at.
    var repDistance = toFloat(raw.repDistanceM)
    if let rep = repDistance, rep <= 0 {
        repDistance = nil
    }
    var intervalAmbiguous = false
    let effectiveDistance: Double
    if let rep = repDistance {
        effectiveDistance = Py.min(rep, distance)
    } else {
        effectiveDistance = distance
        if let suspicion = config.intervalSuspicionM[tag], distance > suspicion {
            intervalAmbiguous = true
        }
    }

    // A rating far from the tier's band is a contradiction, not a pace correction.
    let rpe = normaliseRPE(raw.rpe)
    var rpeMismatch = false
    if let rpe, abs(rpe - tier.rpeMid) > config.rpeContradictionPoints {
        rpeMismatch = true
    }

    var bodyweight = toFloat(raw.bodyweightKg)
    if let weight = bodyweight, !(25.0 <= weight && weight <= 250.0) {
        warnings.append("\(sessionId): bodyweight \(Py.g(weight))kg is outside 25-250; ignored")
        bodyweight = nil
    }

    return Session(
        id: sessionId,
        day: day,
        date: raw.date,
        distanceM: distance,
        timeS: time,
        splitS: split,
        tag: tag,
        strokeRate: strokeRate,
        repDistanceM: repDistance,
        effectiveDistanceM: effectiveDistance,
        intervalAmbiguous: intervalAmbiguous,
        rateMismatch: rateMismatch,
        rpe: rpe,
        rpeMismatch: rpeMismatch,
        bodyweightKg: bodyweight
    )
}

// MARK: - De-duplication

/// `_dedupe_raw`: drop repeated ids, keeping the LAST occurrence. Runs before parsing, so a
/// retried upload never doubles the training load; the later copy is the edited one.
func dedupe(_ raw: [SessionInput], warnings: inout [String], flags: inout [String]) -> [SessionInput] {
    var lastIndex: [String: Int] = [:]
    for (index, session) in raw.enumerated() {
        lastIndex[session.id] = index
    }
    var kept: [SessionInput] = []
    var dropped = 0
    for (index, session) in raw.enumerated() {
        if lastIndex[session.id] != index {
            dropped += 1
            continue
        }
        kept.append(session)
    }
    if dropped > 0 {
        warnings.append("\(dropped) duplicate session(s) by id were ignored; kept the latest copy of each")
        flags.append("duplicate_sessions_removed")
    }
    return kept
}
