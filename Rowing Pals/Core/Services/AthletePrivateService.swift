//
//  AthletePrivateService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// The rower's date of birth and bodyweight (decision 30): private inputs to the prediction
/// algorithm, never shown on a profile. They live in `athlete_private`, which only the rower
/// can write and read directly — not on `profiles`, which every signed-in rower can read. Their
/// club's coaches read them through `coach_athlete_details` (decisions 35 and 107), which leaves out
/// a junior's bodyweight unless a parent or guardian has agreed
/// (docs/migrations/2026-11-17-minimum-age.sql).
enum AthletePrivateService {
    nonisolated struct Details: Equatable, Sendable {
        var birthDate: Date?
        var weightKg: Double?
        /// A junior's parent or guardian agrees to their coaches seeing their bodyweight (decision 107).
        var guardianAgreesWeight = false
    }

    private struct Row: Codable {
        let userId: UUID
        let birthDate: String?
        let weightKg: Double?
        let guardianAgreesWeight: Bool?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case birthDate = "birth_date"
            case weightKg = "weight_kg"
            case guardianAgreesWeight = "guardian_agrees_weight"
        }

        // Every key always sent, so clearing a value writes null.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(userId, forKey: .userId)
            try c.encode(birthDate, forKey: .birthDate)
            try c.encode(weightKg, forKey: .weightKg)
            try c.encode(guardianAgreesWeight ?? false, forKey: .guardianAgreesWeight)
        }
    }

    /// A calendar day as Postgres `date` text, in the rower's own calendar.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func mine() async throws -> Details {
        let userId = try await SupabaseService.shared.auth.session.user.id
        let rows: [Row] = try await SupabaseService.shared
            .from("athlete_private").select("user_id, birth_date, weight_kg, guardian_agrees_weight")
            .eq("user_id", value: userId).execute().value
        guard let row = rows.first else { return Details() }
        return Details(birthDate: row.birthDate.flatMap(dayFormatter.date(from:)), weightKg: row.weightKg,
                       guardianAgreesWeight: row.guardianAgreesWeight ?? false)
    }

    /// Other rowers' details, for a coach (decisions 35 and 107). The database returns only the
    /// rowers the caller coaches, and a junior's bodyweight only with their guardian's agreement;
    /// anyone else is simply missing.
    static func details(for userIds: [UUID]) async throws -> [UUID: Details] {
        guard !userIds.isEmpty else { return [:] }
        struct Params: Encodable { let p_users: [UUID] }
        struct CoachRow: Decodable {
            let userId: UUID
            let birthDate: String?
            let weightKg: Double?
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case birthDate = "birth_date"
                case weightKg = "weight_kg"
            }
        }
        let rows: [CoachRow] = try await SupabaseService.shared
            .rpc("coach_athlete_details", params: Params(p_users: userIds))
            .execute().value
        var details: [UUID: Details] = [:]
        for row in rows {
            details[row.userId] = Details(birthDate: row.birthDate.flatMap(dayFormatter.date(from:)), weightKg: row.weightKg)
        }
        return details
    }

    static func save(_ details: Details) async throws {
        let userId = try await SupabaseService.shared.auth.session.user.id
        let row = Row(
            userId: userId,
            birthDate: details.birthDate.map(dayFormatter.string(from:)),
            weightKg: details.weightKg,
            guardianAgreesWeight: details.guardianAgreesWeight
        )
        try await SupabaseService.shared.from("athlete_private").upsert(row, onConflict: "user_id").execute()
    }

    /// Saves just the date of birth (at sign-up, or the one-time question), leaving any bodyweight
    /// as it is. The database refuses a date that makes someone under 13.
    static func saveBirthDate(_ birthDate: Date) async throws {
        struct BirthDateRow: Encodable {
            let user_id: UUID
            let birth_date: String
        }
        let userId = try await SupabaseService.shared.auth.session.user.id
        try await SupabaseService.shared.from("athlete_private")
            .upsert(BirthDateRow(user_id: userId, birth_date: dayFormatter.string(from: birthDate)), onConflict: "user_id")
            .execute()
    }

    /// The date of birth as the database stores it, for the sign-up metadata.
    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// A stored date of birth back as a date.
    static func day(from text: String) -> Date? { dayFormatter.date(from: text) }
}
