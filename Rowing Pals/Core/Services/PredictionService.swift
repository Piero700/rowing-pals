//
//  PredictionService.swift
//  Rowing Pals
//

import Foundation
import PaceEngine
import Supabase

/// Test-time predictions for the signed-in rower from the Pace Engine (`Packages/PaceEngine`,
/// decisions 30–31). Pure arithmetic over a few dozen rows, so it runs on the phone whenever a
/// screen loads: one read of the rower's recent sessions, then one prediction per distance.
///
/// What feeds the engine (PaceEngine/HANDOFF.md, phase 2): erg sessions only, with a zone;
/// the **main** segment(s), never warm-up or cool-down or the session total (a 2k test plus
/// warm-up and cool-down sent as one 6k "AN" would read as an all-out 6k); the session's own
/// calendar day; the post's id; its effort rating; an interval's rep distance.
enum PredictionService {
    /// The cold-start Population Estimate stays hidden (decision 30): it is shown as "no
    /// prediction yet". Its values are fitted (engine v1.4); showing it is the user's call.
    static let showsPopulationEstimate = false

    /// Days of history read: the engine's 30-day window, plus enough to tell a lapsed rower
    /// ("history outside the window") from a brand-new one.
    private static let historyDays = 60

    /// One prediction per target distance (metres).
    static func predictions(
        for distances: [Double],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> [Double: Prediction] {
        let userId = try await SupabaseService.shared.auth.session.user.id
        async let history = loadHistory(userId: userId, asOf: asOf, calendar: calendar)
        async let athlete = loadAthlete(userId: userId, asOf: asOf, calendar: calendar)
        let (sessions, profile) = try await (history, athlete)

        var predictions: [Double: Prediction] = [:]
        for distance in distances {
            predictions[distance] = PacePredictor.predict(
                history: sessions,
                targetDistance: distance,
                asOf: asOf,
                calendar: calendar,
                athlete: profile
            )
        }
        return predictions
    }

    /// Whether a prediction is a number to show. Insufficient Data never is; a Population
    /// Estimate only once it's switched on.
    static func isShowable(_ prediction: Prediction) -> Bool {
        switch prediction.confidenceScore {
        case .high, .medium, .low: true
        case .populationEstimate: showsPopulationEstimate
        case .insufficientData: false
        }
    }

    // MARK: - Inputs

    /// The columns `SessionRow` reads.
    static let sessionColumns = "id, session_date, zone, rpe, segments(label, position, distance_m, time_ms, split_ms, rate, rep_distance_m)"

    /// One `sessions` row with its segments, as read for the engine.
    struct SessionRow: Decodable {
        struct SegmentRow: Decodable {
            let label: SegmentLabel
            let position: Int
            let distanceM: Int
            let timeMs: Int
            let splitMs: Int?
            let rate: Double?
            let repDistanceM: Int?

            enum CodingKeys: String, CodingKey {
                case label, position, rate
                case distanceM = "distance_m"
                case timeMs = "time_ms"
                case splitMs = "split_ms"
                case repDistanceM = "rep_distance_m"
            }
        }

        let id: UUID
        let sessionDate: String
        let zone: String?
        let rpe: Double?
        let segments: [SegmentRow]

        enum CodingKeys: String, CodingKey {
            case id, zone, rpe, segments
            case sessionDate = "session_date"
        }
    }

    private static func loadHistory(userId: UUID, asOf: Date, calendar: Calendar) async throws -> [SessionInput] {
        let earliest = calendar.date(byAdding: .day, value: -historyDays, to: asOf) ?? asOf
        let rows: [SessionRow] = try await SupabaseService.shared
            .from("sessions")
            .select(sessionColumns)
            .eq("user_id", value: userId)
            .eq("type", value: SessionType.erg.rawValue)
            .gte("session_date", value: isoDay(earliest, calendar: calendar))
            .execute()
            .value
        return history(from: rows, calendar: calendar)
    }

    /// The engine's input: each zoned session's MAIN segment(s) — never warm-up, cool-down or the
    /// session total. A session's first main piece keeps the post's id; any further one adds its
    /// position, so the engine's de-duplication never merges them.
    static func history(from rows: [SessionRow], calendar: Calendar) -> [SessionInput] {
        var history: [SessionInput] = []
        for row in rows {
            guard let zone = row.zone, let tag = Tier.Name(rawValue: zone),
                  let date = day(row.sessionDate, calendar: calendar) else { continue }
            let mains = row.segments.filter { $0.label == .main }.sorted { $0.position < $1.position }
            for (index, segment) in mains.enumerated() {
                history.append(SessionInput(
                    id: index == 0 ? row.id.uuidString : "\(row.id.uuidString)-\(segment.position)",
                    date: date,
                    distanceM: Double(segment.distanceM),
                    tag: tag,
                    timeS: Double(segment.timeMs) / 1000,
                    splitS: segment.splitMs.map { Double($0) / 1000 },
                    strokeRate: segment.rate,
                    repDistanceM: segment.repDistanceM.map(Double.init),
                    rpe: row.rpe
                ))
            }
        }
        return history
    }

    /// Gender from the profile; age and weight from the private table (decision 30). With the
    /// Population Estimate off, none of these changes a prediction yet — the engine anchors on
    /// the rower's own sessions and uses demographics only for the cold-start estimate.
    private static func loadAthlete(userId: UUID, asOf: Date, calendar: Calendar) async throws -> AthleteProfile? {
        struct ProfileRow: Decodable { let gender: RowerGender? }
        let profile: ProfileRow? = try? await SupabaseService.shared
            .from("profiles").select("gender").eq("id", value: userId).single().execute().value
        let details = (try? await AthletePrivateService.mine()) ?? AthletePrivateService.Details()

        return athlete(gender: profile?.gender, details: details, asOf: asOf, calendar: calendar)
    }

    /// The engine's athlete input from a rower's gender and private details; nil with none.
    /// Also used by Coaching for each rower a coach sees (decision 35).
    static func athlete(
        gender: RowerGender?,
        details: AthletePrivateService.Details,
        asOf: Date,
        calendar: Calendar
    ) -> AthleteProfile? {
        let sex: String? = switch gender {
        case .male: "male"
        case .female: "female"
        case nil: nil
        }
        let age = details.birthDate
            .flatMap { calendar.dateComponents([.year], from: $0, to: asOf).year }
            .map(Double.init)
        if sex == nil && age == nil && details.weightKg == nil { return nil }
        return AthleteProfile(age: age, sex: sex, weightKg: details.weightKg)
    }

    static func isoDay(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// `sessions.session_date` ("YYYY-MM-DD", the rower's local day) as that day in `calendar`.
    static func day(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
