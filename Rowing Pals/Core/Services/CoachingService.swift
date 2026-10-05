//
//  CoachingService.swift
//  Rowing Pals
//

import Foundation
import PaceEngine
import Supabase

/// Everything Coaching reads and writes (decisions 34, 35, 39, 40). Reads go straight to the
/// tables — the database lets a coach read their club's rowers, private ones included, and
/// nothing more (docs/migrations/2026-10-05-coaching.sql). Squad changes go through its
/// security-definer functions, which check the caller coaches the club or is an owner or
/// co-owner. Every rower's numbers are worked out from one batched read for the whole club,
/// never one round trip per rower.
enum CoachingService {
    enum CoachingError: LocalizedError {
        case notACoach

        var errorDescription: String? {
            switch self {
            case .notACoach: "Only your club's coaches can open Coaching."
            }
        }
    }

    // MARK: - Squads

    /// The club's squads with their members, alphabetical.
    static func squads(of clubId: UUID) async throws -> [Squad] {
        nonisolated struct Row: Decodable {
            struct Member: Decodable {
                let userId: UUID
                enum CodingKeys: String, CodingKey { case userId = "user_id" }
            }
            let id: UUID
            let name: String
            let members: [Member]
            enum CodingKeys: String, CodingKey {
                case id, name
                case members = "squad_members"
            }
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("squads").select("id, name, squad_members(user_id)").eq("club_id", value: clubId)
            .execute().value
        return rows
            .map { Squad(id: $0.id, name: $0.name, memberIds: Set($0.members.map(\.userId))) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Creates a squad in the caller's club with these members.
    @discardableResult
    static func createSquad(name: String, memberIds: Set<UUID>) async throws -> UUID {
        struct Params: Encodable { let p_name: String }
        let id: UUID = try await SupabaseService.shared
            .rpc("create_squad", params: Params(p_name: name)).execute().value
        try await setMembers(memberIds, of: id)
        return id
    }

    static func renameSquad(_ squadId: UUID, to name: String) async throws {
        struct Params: Encodable { let p_squad: UUID; let p_name: String }
        try await SupabaseService.shared
            .rpc("rename_squad", params: Params(p_squad: squadId, p_name: name)).execute()
    }

    static func deleteSquad(_ squadId: UUID) async throws {
        struct Params: Encodable { let p_squad: UUID }
        try await SupabaseService.shared.rpc("delete_squad", params: Params(p_squad: squadId)).execute()
    }

    /// Replaces the squad's members.
    static func setMembers(_ memberIds: Set<UUID>, of squadId: UUID) async throws {
        struct Params: Encodable { let p_squad: UUID; let p_users: [UUID] }
        try await SupabaseService.shared
            .rpc("set_squad_members", params: Params(p_squad: squadId, p_users: Array(memberIds))).execute()
    }

    // MARK: - Read-only posts

    /// Of `postIds`, the ones the viewer sees only because they coach the author: they can read
    /// them but not comment or react (decision 40). Empty for anyone who coaches no club. If the
    /// check fails, nothing is marked — the database still refuses the comment or reaction.
    static func readOnlyPosts(among postIds: [UUID]) async -> Set<UUID> {
        guard !postIds.isEmpty, (try? await ViewerContext.shared.current())?.isCoach == true else { return [] }
        struct Params: Encodable { let p_ids: [UUID] }
        guard let open: [UUID] = try? await SupabaseService.shared
            .rpc("sessions_i_can_interact_with", params: Params(p_ids: postIds)).execute().value else { return [] }
        return Set(postIds).subtracting(open)
    }

    // MARK: - The Rowers list

    struct Roster {
        let clubId: UUID
        let clubName: String
        let rowers: [CoachRower]
        let squads: [Squad]
    }

    /// Every rowing member of the club the caller coaches, with this week's numbers.
    static func roster(asOf: Date = Date(), calendar: Calendar = .current) async throws -> Roster {
        let viewer = try await ViewerContext.shared.current()
        guard viewer.isCoach, let clubId = viewer.clubId else { throw CoachingError.notACoach }
        let raw = try await load(clubId: clubId, only: nil, asOf: asOf, calendar: calendar)
        let rowers = raw.profiles.map { makeRower($0, raw: raw, asOf: asOf, calendar: calendar) }
        return Roster(clubId: clubId, clubName: viewer.clubName ?? "Your club", rowers: rowers, squads: raw.squads)
    }

    // MARK: - One rower

    /// One test on a rower's page: their latest result at that test, and whether it's their best.
    struct TestLine: Identifiable, Equatable {
        let key: String
        let label: String
        let setAt: Date
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int
        let isDurationBased: Bool
        let isBest: Bool
        var id: String { key }
    }

    /// A post's square on a rower's page.
    struct PostTile: Identifiable, Equatable {
        let sessionId: UUID
        let photoURL: URL?
        var id: UUID { sessionId }
    }

    struct ZoneShare: Equatable {
        let zone: Tier.Name
        let share: Double
    }

    struct RowerDetail {
        let rower: CoachRower
        let age: Int?
        let weightKg: Double?
        /// Metres for each of the last 8 weeks, oldest first; `weekStarts` dates them.
        let weeklyMetres: [Int]
        let weekStarts: [Date]
        /// The last 4 weeks' metres by zone, UT2 first; empty with no zoned sessions.
        let zoneMix: [ZoneShare]
        /// Average effort per session each week for 8 weeks (nil: no ratings that week).
        let weeklyEffort: [Double?]
        /// The 4-week average (the dashed line) and the last 7 days' average.
        let monthEffort: Double?
        let recentEffort: Double?
        let tests: [TestLine]
        let posts: [PostTile]
    }

    static func rower(_ userId: UUID, asOf: Date = Date(), calendar: Calendar = .current) async throws -> RowerDetail {
        let viewer = try await ViewerContext.shared.current()
        guard viewer.isCoach, let clubId = viewer.clubId else { throw CoachingError.notACoach }
        async let rawTask = load(clubId: clubId, only: userId, asOf: asOf, calendar: calendar)
        async let allTestsTask = tests(of: userId)
        async let postsTask = posts(of: userId)
        async let clubTestsTask = try? await ClubTestService.mine()
        let (raw, allTests, posts, clubTests) = try await (rawTask, allTestsTask, postsTask, clubTestsTask)
        guard let profile = raw.profiles.first else { throw CoachingError.notACoach }

        let rower = makeRower(profile, raw: raw, asOf: asOf, calendar: calendar)
        let details = raw.privateDetails[userId] ?? AthletePrivateService.Details()

        let days = raw.totals.compactMap { row in
            PredictionService.day(row.day, calendar: calendar).map { (day: $0, metres: row.distanceM) }
        }
        var metresByZone: [Tier.Name: Int] = [:]
        for session in raw.sessions {
            guard let zone = session.row.zone.flatMap(Tier.Name.init(rawValue:)),
                  let day = PredictionService.day(session.row.sessionDate, calendar: calendar),
                  CoachingRules.daysBetween(day, and: asOf, calendar: calendar) < 28 else { continue }
            metresByZone[zone, default: 0] += session.row.segments.reduce(0) { $0 + $1.distanceM }
        }
        let ratings = ratings(raw.sessions, calendar: calendar)
        let testCatalogue = StandardTest.all + (clubTests?.tests.map(\.asTest) ?? [])

        return RowerDetail(
            rower: rower,
            age: details.birthDate.flatMap { CoachingRules.age(birthDate: $0, asOf: asOf, calendar: calendar) },
            weightKg: details.weightKg,
            weeklyMetres: CoachingRules.weeklyMetres(days, asOf: asOf, calendar: calendar),
            weekStarts: CoachingRules.weekStarts(weeks: 8, asOf: asOf, calendar: calendar),
            zoneMix: CoachingRules.zoneMix(metresByZone).map { ZoneShare(zone: $0.zone, share: $0.share) },
            weeklyEffort: CoachingRules.weeklyEffort(ratings, asOf: asOf, calendar: calendar),
            monthEffort: CoachingRules.averageEffort(ratings, days: 28, asOf: asOf, calendar: calendar),
            recentEffort: CoachingRules.averageEffort(ratings, days: 7, asOf: asOf, calendar: calendar),
            tests: testLines(allTests, catalogue: testCatalogue),
            posts: posts
        )
    }

    // MARK: - Reading

    nonisolated private struct ProfileRow: Decodable {
        let id: UUID
        let displayName: String
        let avatarPath: String?
        let category: RowerCategory
        let gender: RowerGender?
        let isPrivate: Bool?
        let isCoach: Bool?
        let weeklyTargetM: Int
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id, category, gender
            case displayName = "display_name"
            case avatarPath = "avatar_path"
            case isPrivate = "is_private"
            case isCoach = "is_coach"
            case weeklyTargetM = "weekly_target_m"
            case createdAt = "created_at"
        }
    }

    nonisolated private struct TotalRow: Decodable {
        let userId: UUID
        let day: String
        let distanceM: Int
        let sessionCount: Int
        enum CodingKeys: String, CodingKey {
            case day
            case userId = "user_id"
            case distanceM = "distance_m"
            case sessionCount = "session_count"
        }
    }

    /// A session read for the engine, with whose it is.
    nonisolated private struct UserSessionRow: Decodable {
        let userId: UUID
        let row: PredictionService.SessionRow

        enum CodingKeys: String, CodingKey { case userId = "user_id" }

        init(from decoder: Decoder) throws {
            userId = try decoder.container(keyedBy: CodingKeys.self).decode(UUID.self, forKey: .userId)
            row = try PredictionService.SessionRow(from: decoder)
        }
    }

    nonisolated private struct TestRow: Decodable {
        let userId: UUID
        let distanceKey: String
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int
        let setAt: Date
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case distanceKey = "distance_key"
            case distanceM = "distance_m"
            case timeMs = "time_ms"
            case splitMs = "split_ms"
            case setAt = "set_at"
        }
    }

    private struct Raw {
        let profiles: [ProfileRow]
        let squads: [Squad]
        let totals: [TotalRow]
        let sessions: [UserSessionRow]
        let twoKs: [TestRow]
        let privateDetails: [UUID: AthletePrivateService.Details]
    }

    /// The club's rowing members (or just `only`) and the last `historyDays` days of everything
    /// the list needs: two rounds, all reads in each running at once.
    private static func load(clubId: UUID, only: UUID?, asOf: Date, calendar: Calendar) async throws -> Raw {
        var profileQuery = SupabaseService.shared
            .from("profiles")
            .select("id, display_name, avatar_path, category, gender, is_private, is_coach, weekly_target_m, created_at")
            .eq("club_id", value: clubId)
            // Coach-only accounts aren't rowers to coach (decision 34).
            .eq("is_rower", value: true)
        if let only { profileQuery = profileQuery.eq("id", value: only) }
        async let profilesTask: [ProfileRow] = profileQuery.execute().value
        async let squadsTask = squads(of: clubId)
        let (profiles, squads) = try await (profilesTask, squadsTask)
        let ids = profiles.map(\.id)
        guard !ids.isEmpty else {
            return Raw(profiles: [], squads: squads, totals: [], sessions: [], twoKs: [], privateDetails: [:])
        }

        let earliest = calendar.date(byAdding: .day, value: -CoachingRules.historyDays, to: asOf) ?? asOf
        let since = PredictionService.isoDay(earliest, calendar: calendar)
        async let totalsTask: [TotalRow] = SupabaseService.shared
            .from("daily_totals").select("user_id, day, distance_m, session_count")
            .in("user_id", values: ids).gte("day", value: since)
            .execute().value
        async let sessionsTask: [UserSessionRow] = SupabaseService.shared
            .from("sessions").select("user_id, " + PredictionService.sessionColumns)
            .in("user_id", values: ids).eq("type", value: SessionType.erg.rawValue).gte("session_date", value: since)
            .execute().value
        async let twoKsTask: [TestRow] = SupabaseService.shared
            .from("test_results").select("user_id, distance_key, distance_m, time_ms, split_ms, set_at")
            .in("user_id", values: ids).eq("distance_key", value: "2k")
            .execute().value
        // Before the coaching migration a coach can't read these; predictions then use
        // sessions alone, as they do with the Population Estimate off.
        async let privateTask = (try? await AthletePrivateService.details(for: ids)) ?? [:]
        let (totals, sessions, twoKs, privateDetails) = try await (totalsTask, sessionsTask, twoKsTask, privateTask)
        return Raw(profiles: profiles, squads: squads, totals: totals, sessions: sessions, twoKs: twoKs, privateDetails: privateDetails)
    }

    private static func ratings(_ sessions: [UserSessionRow], calendar: Calendar) -> [CoachingRules.Rating] {
        sessions.compactMap { session in
            guard let rpe = session.row.rpe, let day = PredictionService.day(session.row.sessionDate, calendar: calendar) else { return nil }
            return CoachingRules.Rating(day: day, rpe: rpe)
        }
    }

    private static func makeRower(_ profile: ProfileRow, raw: Raw, asOf: Date, calendar: Calendar) -> CoachRower {
        let weekStart = CoachingRules.weekStart(of: asOf, calendar: calendar)
        var weekMetres = 0
        var weekSessions = 0
        var lastDay: Date?
        for total in raw.totals where total.userId == profile.id {
            guard let day = PredictionService.day(total.day, calendar: calendar) else { continue }
            if day >= weekStart {
                weekMetres += total.distanceM
                weekSessions += total.sessionCount
            }
            if total.sessionCount > 0, day > (lastDay ?? .distantPast) { lastDay = day }
        }
        let daysSinceSession = lastDay.map { CoachingRules.daysBetween($0, and: asOf, calendar: calendar) }

        let mine = raw.sessions.filter { $0.userId == profile.id }
        let history = PredictionService.history(from: mine.map(\.row), calendar: calendar)
        let athlete = PredictionService.athlete(
            gender: profile.gender,
            details: raw.privateDetails[profile.id] ?? AthletePrivateService.Details(),
            asOf: asOf,
            calendar: calendar
        )
        let prediction = PacePredictor.predict(
            history: history, targetDistance: 2000, asOf: asOf, calendar: calendar, athlete: athlete
        )
        let showable = PredictionService.isShowable(prediction) ? prediction : nil
        let effort = CoachingRules.effortChangePercent(ratings(mine, calendar: calendar), asOf: asOf, calendar: calendar)

        let squads = raw.squads.filter { $0.memberIds.contains(profile.id) }
        return CoachRower(
            id: profile.id,
            displayName: profile.displayName,
            avatarPath: profile.avatarPath,
            category: profile.category,
            gender: profile.gender,
            isPrivate: profile.isPrivate ?? false,
            isCoach: profile.isCoach ?? false,
            squadNames: squads.map(\.name),
            squadIds: Set(squads.map(\.id)),
            weekMetres: weekMetres,
            weekSessions: weekSessions,
            weeklyTargetM: profile.weeklyTargetM,
            daysSinceSession: daysSinceSession,
            twoKBestMs: raw.twoKs.filter { $0.userId == profile.id }.map(\.timeMs).min(),
            prediction: showable,
            // Flags read the engine even when its number isn't shown (a thin history can still
            // disagree with itself).
            flags: CoachingRules.flags(
                prediction: prediction,
                daysSinceSession: daysSinceSession,
                accountAgeDays: CoachingRules.daysBetween(profile.createdAt, and: asOf, calendar: calendar),
                effortChangePercent: effort
            ),
            shortfallM: CoachingRules.shortfallM(
                weekMetres: weekMetres, weeklyTargetM: profile.weeklyTargetM, asOf: asOf, calendar: calendar
            )
        )
    }

    private static func tests(of userId: UUID) async throws -> [TestRow] {
        try await SupabaseService.shared
            .from("test_results").select("user_id, distance_key, distance_m, time_ms, split_ms, set_at")
            .eq("user_id", value: userId).order("set_at", ascending: false)
            .execute().value
    }

    /// Latest result per test, in the catalogue's order, marked when it's also the best.
    private static func testLines(_ rows: [TestRow], catalogue: [StandardTest]) -> [TestLine] {
        catalogue.compactMap { test in
            let results = rows.filter { $0.distanceKey == test.key }
            guard let latest = results.max(by: { $0.setAt < $1.setAt }) else { return nil }
            let best = test.isDurationBased
                ? results.max { $0.distanceM < $1.distanceM }
                : results.min { $0.timeMs < $1.timeMs }
            return TestLine(
                key: test.key, label: test.label, setAt: latest.setAt, distanceM: latest.distanceM,
                timeMs: latest.timeMs, splitMs: latest.splitMs, isDurationBased: test.isDurationBased,
                isBest: best.map { test.isDurationBased ? $0.distanceM == latest.distanceM : $0.timeMs == latest.timeMs } ?? false
            )
        }
    }

    /// Their latest posts' monitor photos, newest first, with links signed in one request.
    private static func posts(of userId: UUID) async throws -> [PostTile] {
        nonisolated struct Row: Decodable {
            struct Segment: Decodable {
                let position: Int
                let monitorPhotoPath: String?
                enum CodingKeys: String, CodingKey {
                    case position
                    case monitorPhotoPath = "monitor_photo_path"
                }
            }
            let id: UUID
            let segments: [Segment]
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("sessions").select("id, segments(position, monitor_photo_path)")
            .eq("user_id", value: userId).order("posted_at", ascending: false).limit(30)
            .execute().value
        let paths = rows.map { $0.segments.min { $0.position < $1.position }?.monitorPhotoPath }
        var signed: [String: URL] = [:]
        let toSign = paths.compactMap { $0 }
        if !toSign.isEmpty,
           let results = try? await SupabaseService.shared.storage.from("monitors").createSignedURLs(paths: toSign, expiresIn: 3600) {
            for result in results {
                if case .success(let path, let url) = result { signed[path] = url }
            }
        }
        return zip(rows, paths).map { row, path in PostTile(sessionId: row.id, photoURL: path.flatMap { signed[$0] }) }
    }
}
