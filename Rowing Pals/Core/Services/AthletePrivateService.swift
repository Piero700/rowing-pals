//
//  AthletePrivateService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// The rower's date of birth and bodyweight (decision 30): private inputs to the prediction
/// algorithm, never shown on a profile. They live in `athlete_private`, which only the rower
/// can write and only the rower and their club's coaches can read (decision 35;
/// docs/migrations/2026-10-05-pace-engine-inputs.sql and 2026-10-05-coaching.sql) — not on
/// `profiles`, which every signed-in rower can read.
enum AthletePrivateService {
    struct Details: Equatable {
        var birthDate: Date?
        var weightKg: Double?
    }

    private struct Row: Codable {
        let userId: UUID
        let birthDate: String?
        let weightKg: Double?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case birthDate = "birth_date"
            case weightKg = "weight_kg"
        }

        // Both keys always sent, so clearing a value writes null.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(userId, forKey: .userId)
            try c.encode(birthDate, forKey: .birthDate)
            try c.encode(weightKg, forKey: .weightKg)
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
            .from("athlete_private").select("user_id, birth_date, weight_kg")
            .eq("user_id", value: userId).execute().value
        guard let row = rows.first else { return Details() }
        return Details(birthDate: row.birthDate.flatMap(dayFormatter.date(from:)), weightKg: row.weightKg)
    }

    /// Other rowers' details, for a coach (decision 35). The database returns only the rowers
    /// the caller coaches; anyone else is simply missing.
    static func details(for userIds: [UUID]) async throws -> [UUID: Details] {
        guard !userIds.isEmpty else { return [:] }
        let rows: [Row] = try await SupabaseService.shared
            .from("athlete_private").select("user_id, birth_date, weight_kg")
            .in("user_id", values: userIds).execute().value
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
            weightKg: details.weightKg
        )
        try await SupabaseService.shared.from("athlete_private").upsert(row, onConflict: "user_id").execute()
    }
}
