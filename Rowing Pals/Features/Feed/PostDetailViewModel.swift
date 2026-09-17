//
//  PostDetailViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns one post's full detail — every segment, the gold test-result
/// banner (if the Main segment was confirmed as a test), reactions,
/// comments, and follow status for its author. Reactions and comments
/// arrive live via Supabase Realtime, not just on load.
@Observable
final class PostDetailViewModel {
    struct Author {
        let id: UUID
        let displayName: String
        let category: RowerCategory
        let gender: RowerGender?
        let club: String?
    }

    struct DetailSegment: Identifiable {
        let id: UUID
        let label: SegmentLabel
        let position: Int
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int?
        let rate: Double?
        let monitorPhotoPath: String?
    }

    struct TestBanner {
        let distanceLabel: String
        /// Time for a distance test, distance for a duration one.
        let valueLabel: String
        let isPersonalBest: Bool
        let overallRank: Int?
        /// e.g. "novice men" / "senior women" — nil if the author's own
        /// category/gender snapshot can't be labelled (shouldn't happen
        /// for a real confirmed test, but the banner degrades gracefully).
        let categoryLabel: String?
        let categoryRank: Int?
    }

    struct ReactionSummary: Identifiable {
        let kind: String
        var id: String { kind }
        var count: Int
        var reactedByMe: Bool
    }

    struct CommentDisplay: Identifiable {
        let id: UUID
        let authorId: UUID
        let authorName: String
        let body: String
        let createdAt: Date
    }

    /// The four the design brief names explicitly, always shown even at
    /// zero; a viewer can react with more via the "+ " picker, and those
    /// only appear once somebody has actually used one.
    static let coreReactionKinds = ["fire", "grimace", "clap", "eyes"]
    static let extraReactionKinds = ["muscle", "wow", "boat"]

    let sessionId: UUID

    var author: Author?
    var type: SessionType = .erg
    var caption: String?
    var totalDistanceM = 0
    var totalTimeMs = 0
    var avgSplitMs: Int?
    var avgRate: Double?
    var photoVerified = false
    var loggedLate = false
    var postedAt = Date()
    var segments: [DetailSegment] = []
    var monitorURLs: [String: URL] = [:]
    var selfieURL: URL?
    /// The author's current streak — a single user here, so this computes
    /// `StreakCalculator.streak(...)` directly from their own `daily_totals`
    /// rows rather than going through a batched multi-author fetch (see
    /// FeedViewModel/leaderboard view models for that pattern, used where
    /// several authors are on screen at once).
    var authorStreakDays = 0

    var testBanner: TestBanner?
    var reactions: [ReactionSummary] = []
    var comments: [CommentDisplay] = []

    var isFollowingAuthor = false
    var isOwnPost = false
    var isBlocked = false

    var isLoading = false
    var errorMessage: String?

    private var ownUserId: UUID?
    private var ownDisplayName = ""
    private var realtimeChannel: RealtimeChannelV2?

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            ownUserId = userId

            struct SessionRow: Decodable {
                struct AuthorRow: Decodable {
                    struct Club: Decodable { let name: String }
                    let id: UUID
                    let displayName: String
                    let category: RowerCategory
                    let gender: RowerGender?
                    let club: Club?
                    enum CodingKeys: String, CodingKey {
                        case id
                        case displayName = "display_name"
                        case category, gender
                        case club = "clubs"
                    }
                }
                struct SegmentRow: Decodable {
                    let id: UUID
                    let label: SegmentLabel
                    let position: Int
                    let distanceM: Int
                    let timeMs: Int
                    let splitMs: Int?
                    let rate: Double?
                    let monitorPhotoPath: String?
                    enum CodingKeys: String, CodingKey {
                        case id, label, position
                        case distanceM = "distance_m"
                        case timeMs = "time_ms"
                        case splitMs = "split_ms"
                        case rate
                        case monitorPhotoPath = "monitor_photo_path"
                    }
                }

                let userId: UUID
                let type: SessionType
                let caption: String?
                let totalDistanceM: Int
                let totalTimeMs: Int
                let avgSplitMs: Int?
                let avgRate: Double?
                let photoVerified: Bool
                let loggedLate: Bool
                let postedAt: Date
                let author: AuthorRow
                let segments: [SegmentRow]

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case type, caption
                    case totalDistanceM = "total_distance_m"
                    case totalTimeMs = "total_time_ms"
                    case avgSplitMs = "avg_split_ms"
                    case avgRate = "avg_rate"
                    case photoVerified = "photo_verified"
                    case loggedLate = "logged_late"
                    case postedAt = "posted_at"
                    case author = "profiles"
                    case segments
                }
            }

            let row: SessionRow = try await SupabaseService.shared
                .from("sessions")
                .select("""
                user_id, type, caption, total_distance_m, total_time_ms, avg_split_ms, avg_rate, \
                photo_verified, logged_late, posted_at, \
                profiles!sessions_user_id_fkey(id, display_name, category, gender, clubs(name)), \
                segments(id, label, position, distance_m, time_ms, split_ms, rate, monitor_photo_path)
                """)
                .eq("id", value: sessionId)
                .single()
                .execute()
                .value

            author = Author(id: row.author.id, displayName: row.author.displayName, category: row.author.category, gender: row.author.gender, club: row.author.club?.name)
            type = row.type
            caption = row.caption
            totalDistanceM = row.totalDistanceM
            totalTimeMs = row.totalTimeMs
            avgSplitMs = row.avgSplitMs
            avgRate = row.avgRate
            photoVerified = row.photoVerified
            loggedLate = row.loggedLate
            postedAt = row.postedAt
            segments = row.segments
                .sorted { $0.position < $1.position }
                .map { DetailSegment(id: $0.id, label: $0.label, position: $0.position, distanceM: $0.distanceM, timeMs: $0.timeMs, splitMs: $0.splitMs, rate: $0.rate, monitorPhotoPath: $0.monitorPhotoPath) }
            isOwnPost = row.userId == userId

            async let photos: Void = fetchPhotoURLs(authorId: row.userId)
            async let banner = Self.loadTestBanner(sessionId: sessionId, authorId: row.userId)
            async let reactionSummaries = Self.loadReactions(sessionId: sessionId, viewerId: userId)
            async let commentList = Self.loadComments(sessionId: sessionId)
            async let following: Bool = row.userId == userId ? false : Self.isFollowing(follower: userId, followee: row.userId)
            async let ownName: String = row.userId == userId ? row.author.displayName : Self.fetchDisplayName(userId: userId)
            async let authorStreak: Int = Self.fetchStreak(userId: row.userId)

            let (_, bannerResult, reactionsResult, commentsResult, followingResult, ownNameResult, authorStreakResult) = try await (photos, banner, reactionSummaries, commentList, following, ownName, authorStreak)
            testBanner = bannerResult
            reactions = reactionsResult
            comments = commentsResult
            isFollowingAuthor = followingResult
            ownDisplayName = ownNameResult
            authorStreakDays = authorStreakResult

            subscribeRealtime()
            errorMessage = nil
        } catch {
            print("Post detail load failed (\(sessionId)): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        guard let realtimeChannel else { return }
        Task { await SupabaseService.shared.removeChannel(realtimeChannel) }
    }

    // MARK: - Photos

    @MainActor
    private func fetchPhotoURLs(authorId: UUID) async {
        let monitorPaths = segments.compactMap(\.monitorPhotoPath)
        async let monitors = Self.signURLs(bucket: "monitors", paths: monitorPaths)
        async let selfies = Self.signURLs(bucket: "selfies", paths: [FeedViewModel.selfiePath(userId: authorId, sessionId: sessionId)])
        let (monitorResults, selfieResults) = await (monitors, selfies)
        for (path, url) in monitorResults { monitorURLs[path] = url }
        selfieURL = selfieResults.first?.1
    }

    private static func signURLs(bucket: String, paths: [String]) async -> [(String, URL)] {
        guard !paths.isEmpty else { return [] }
        guard let results = try? await SupabaseService.shared.storage.from(bucket).createSignedURLs(paths: paths, expiresIn: 3600) else { return [] }
        return results.compactMap { result in
            switch result {
            case .success(let path, let signedURL): (path, signedURL)
            case .failure: nil
            }
        }
    }

    // MARK: - Streak

    /// One user's `daily_totals`, unfiltered — the walk can legitimately
    /// reach back up to 730 days — fed into `StreakCalculator.streak(...)`.
    /// Best-effort: an empty result (network hiccup) just reads back as no
    /// streak rather than failing the whole post load.
    private static func fetchStreak(userId: UUID) async -> Int {
        struct Row: Decodable {
            let day: String
            let sessionCount: Int
            enum CodingKeys: String, CodingKey { case day; case sessionCount = "session_count" }
        }
        guard let rows: [Row] = try? await SupabaseService.shared
            .from("daily_totals")
            .select("day, session_count")
            .eq("user_id", value: userId)
            .execute()
            .value
        else { return 0 }
        let activeDays = Set(rows.filter { $0.sessionCount > 0 }.map(\.day))
        return StreakCalculator.streak(activeDays: activeDays)
    }

    // MARK: - Gold test-result banner

    private static func loadTestBanner(sessionId: UUID, authorId: UUID) async throws -> TestBanner? {
        struct TestRow: Decodable {
            let distanceKey: String
            let distanceM: Int
            let timeMs: Int
            let genderAtTime: RowerGender
            let categoryAtTime: RowerCategory
            enum CodingKeys: String, CodingKey {
                case distanceKey = "distance_key"
                case distanceM = "distance_m"
                case timeMs = "time_ms"
                case genderAtTime = "gender_at_time"
                case categoryAtTime = "category_at_time"
            }
        }

        let matches: [TestRow] = try await SupabaseService.shared
            .from("test_results")
            .select("distance_key, distance_m, time_ms, gender_at_time, category_at_time")
            .eq("session_id", value: sessionId)
            .execute()
            .value
        guard let thisResult = matches.first, let test = StandardTest.all.first(where: { $0.key == thisResult.distanceKey }) else { return nil }

        struct OwnRow: Decodable {
            let distanceM: Int
            let timeMs: Int
            enum CodingKeys: String, CodingKey { case distanceM = "distance_m"; case timeMs = "time_ms" }
        }
        let ownResults: [OwnRow] = try await SupabaseService.shared
            .from("test_results")
            .select("distance_m, time_ms")
            .eq("user_id", value: authorId)
            .eq("distance_key", value: thisResult.distanceKey)
            .execute()
            .value
        let ownBest = test.isDurationBased ? ownResults.map(\.distanceM).max() : ownResults.map(\.timeMs).min()
        let isPersonalBest = test.isDurationBased ? ownBest == thisResult.distanceM : ownBest == thisResult.timeMs

        async let overallRank = rank(of: authorId, distanceKey: thisResult.distanceKey, isDurationBased: test.isDurationBased, gender: thisResult.genderAtTime, category: nil)
        async let categoryRank = rank(of: authorId, distanceKey: thisResult.distanceKey, isDurationBased: test.isDurationBased, gender: thisResult.genderAtTime, category: thisResult.categoryAtTime)
        let (overall, category) = try await (overallRank, categoryRank)

        let genderWord = thisResult.genderAtTime == .male ? "men" : "women"
        let categoryLabel = "\(thisResult.categoryAtTime.rawValue) \(genderWord)"

        return TestBanner(
            distanceLabel: test.label,
            // Duration tests: distance covered, unit-aware. Distance tests:
            // total time taken to finish — elapsed time, not a split.
            valueLabel: test.isDurationBased ? thisResult.distanceM.formattedDistance(unit: .current) : thisResult.timeMs.formattedDurationMs,
            isPersonalBest: isPersonalBest,
            overallRank: overall,
            categoryLabel: categoryLabel,
            categoryRank: category
        )
    }

    /// 1-based rank of `userId` among all rowers of `gender` (and, if
    /// given, `category`) for `distanceKey` — best result per rower only,
    /// same reduction rule as the test leaderboard (task 14).
    private static func rank(of userId: UUID, distanceKey: String, isDurationBased: Bool, gender: RowerGender, category: RowerCategory?) async throws -> Int? {
        struct Row: Decodable {
            let userId: UUID
            let distanceM: Int
            let timeMs: Int
            enum CodingKeys: String, CodingKey { case userId = "user_id"; case distanceM = "distance_m"; case timeMs = "time_ms" }
        }

        var query = SupabaseService.shared
            .from("test_results")
            .select("user_id, distance_m, time_ms")
            .eq("distance_key", value: distanceKey)
            .eq("gender_at_time", value: gender.rawValue)
        if let category { query = query.eq("category_at_time", value: category.rawValue) }

        let rows: [Row] = try await query.execute().value

        var bestByUser: [UUID: Row] = [:]
        for row in rows {
            guard let existing = bestByUser[row.userId] else { bestByUser[row.userId] = row; continue }
            let isBetter = isDurationBased ? row.distanceM > existing.distanceM : row.timeMs < existing.timeMs
            if isBetter { bestByUser[row.userId] = row }
        }

        let orderedIds = bestByUser.values
            .sorted { isDurationBased ? $0.distanceM > $1.distanceM : $0.timeMs < $1.timeMs }
            .map(\.userId)
        return orderedIds.firstIndex(of: userId).map { $0 + 1 }
    }

    // MARK: - Reactions

    private static func loadReactions(sessionId: UUID, viewerId: UUID) async throws -> [ReactionSummary] {
        struct Row: Decodable {
            let userId: UUID
            let kind: String
            enum CodingKeys: String, CodingKey { case userId = "user_id"; case kind }
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("reactions")
            .select("user_id, kind")
            .eq("session_id", value: sessionId)
            .execute()
            .value
        return summarize(rows.map { ($0.kind, $0.userId) }, viewerId: viewerId)
    }

    private static func summarize(_ rows: [(kind: String, userId: UUID)], viewerId: UUID) -> [ReactionSummary] {
        var counts: [String: Int] = [:]
        var mine: Set<String> = []
        for row in rows {
            counts[row.kind, default: 0] += 1
            if row.userId == viewerId { mine.insert(row.kind) }
        }
        let extraPresent = counts.keys.filter { !coreReactionKinds.contains($0) }
        let kinds = coreReactionKinds + extraPresent.sorted()
        return kinds.map { ReactionSummary(kind: $0, count: counts[$0] ?? 0, reactedByMe: mine.contains($0)) }
    }

    @MainActor
    func toggleReaction(kind: String) async {
        guard let userId = ownUserId else { return }
        let isReacted = reactions.first { $0.kind == kind }?.reactedByMe ?? false

        // Optimistic local update — the realtime echo of our own write
        // arrives moments later and is a no-op against state already applied.
        applyReactionChange(kind: kind, userId: userId, isInsert: !isReacted)

        do {
            if isReacted {
                try await SupabaseService.shared
                    .from("reactions")
                    .delete()
                    .eq("session_id", value: sessionId)
                    .eq("user_id", value: userId)
                    .eq("kind", value: kind)
                    .execute()
            } else {
                try await SupabaseService.shared
                    .from("reactions")
                    .insert(Reaction(sessionId: sessionId, userId: userId, kind: kind, createdAt: Date()))
                    .execute()
            }
        } catch {
            // Roll back the optimistic change on failure.
            applyReactionChange(kind: kind, userId: userId, isInsert: isReacted)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func applyReactionChange(kind: String, userId: UUID, isInsert: Bool) {
        if let index = reactions.firstIndex(where: { $0.kind == kind }) {
            reactions[index].count = max(0, reactions[index].count + (isInsert ? 1 : -1))
            if userId == ownUserId { reactions[index].reactedByMe = isInsert }
        } else if isInsert {
            reactions.append(ReactionSummary(kind: kind, count: 1, reactedByMe: userId == ownUserId))
        }
    }

    // MARK: - Comments

    private static func loadComments(sessionId: UUID) async throws -> [CommentDisplay] {
        struct Row: Decodable {
            struct Author: Decodable { let displayName: String
                enum CodingKeys: String, CodingKey { case displayName = "display_name" }
            }
            let id: UUID
            let userId: UUID
            let body: String
            let createdAt: Date
            let author: Author
            enum CodingKeys: String, CodingKey {
                case id, body
                case userId = "user_id"
                case createdAt = "created_at"
                case author = "profiles"
            }
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("comments")
            .select("id, user_id, body, created_at, profiles(display_name)")
            .eq("session_id", value: sessionId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { CommentDisplay(id: $0.id, authorId: $0.userId, authorName: $0.author.displayName, body: $0.body, createdAt: $0.createdAt) }
    }

    @MainActor
    func postComment(body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userId = ownUserId else { return }
        // Filtering, task 17 — checked before the insert, not after.
        guard !TextFilterService.isBlocked(trimmed) else {
            errorMessage = "That comment isn't allowed. Please rephrase it."
            return
        }
        let newComment = Comment(id: UUID(), sessionId: sessionId, userId: userId, body: trimmed, createdAt: Date())
        do {
            try await SupabaseService.shared
                .from("comments")
                .insert(newComment)
                .execute()
            // Appended locally immediately, not left to the realtime echo —
            // found via real device testing that the echo of a comment this
            // same client just wrote isn't reliably arriving, so the post
            // only ever showed up after a full reload. appendComment's own
            // id-based dedup still guards against a double-add on the
            // (now best-effort) chance the echo does also arrive.
            appendComment(CommentDisplay(id: newComment.id, authorId: userId, authorName: ownDisplayName, body: trimmed, createdAt: newComment.createdAt))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func fetchDisplayName(userId: UUID) async throws -> String {
        struct Row: Decodable { let displayName: String
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
        let row: Row = try await SupabaseService.shared
            .from("profiles")
            .select("display_name")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return row.displayName
    }

    // MARK: - Follow

    private static func isFollowing(follower: UUID, followee: UUID) async throws -> Bool {
        struct Row: Decodable { let followerId: UUID
            enum CodingKeys: String, CodingKey { case followerId = "follower_id" }
        }
        let rows: [Row] = try await SupabaseService.shared
            .from("follows")
            .select("follower_id")
            .eq("follower_id", value: follower)
            .eq("followee_id", value: followee)
            .execute()
            .value
        return !rows.isEmpty
    }

    @MainActor
    func toggleFollow() async {
        guard let userId = ownUserId, let authorId = author?.id, !isOwnPost else { return }
        let wasFollowing = isFollowingAuthor
        isFollowingAuthor.toggle()
        do {
            if wasFollowing {
                try await SupabaseService.shared
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: userId)
                    .eq("followee_id", value: authorId)
                    .execute()
            } else {
                struct NewFollow: Encodable {
                    let followerId: UUID
                    let followeeId: UUID
                    enum CodingKeys: String, CodingKey { case followerId = "follower_id"; case followeeId = "followee_id" }
                }
                try await SupabaseService.shared
                    .from("follows")
                    .insert(NewFollow(followerId: userId, followeeId: authorId))
                    .execute()
            }
        } catch {
            isFollowingAuthor = wasFollowing
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Blocking and reporting (task 17)

    /// Blocking the author from a post, per the task's own wording — there
    /// isn't a separate "other rower's profile" screen yet to block from
    /// there too. Feed exclusion is enforced by `FeedViewModel`'s query,
    /// not here.
    @MainActor
    func blockAuthor() async {
        guard let userId = ownUserId, let authorId = author?.id, !isOwnPost else { return }
        do {
            try await SupabaseService.shared
                .from("blocks")
                .insert(Block(blockerId: userId, blockedId: authorId, createdAt: Date()))
                .execute()
            isBlocked = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func reportPost(reason: String) async -> Bool {
        guard let userId = ownUserId else { return false }
        do {
            try await SupabaseService.shared
                .from("reports")
                .insert(Report(id: UUID(), reporterId: userId, sessionId: sessionId, commentId: nil, reason: reason, status: "open", createdAt: Date()))
                .execute()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func isOwnComment(_ comment: CommentDisplay) -> Bool {
        comment.authorId == ownUserId
    }

    @MainActor
    func reportComment(_ commentId: UUID, reason: String) async -> Bool {
        guard let userId = ownUserId else { return false }
        do {
            try await SupabaseService.shared
                .from("reports")
                .insert(Report(id: UUID(), reporterId: userId, sessionId: nil, commentId: commentId, reason: reason, status: "open", createdAt: Date()))
                .execute()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Realtime

    /// New reactions/comments from anyone (including another device signed
    /// into this same account) arrive here without a manual refresh —
    /// task 16's own verify step. Own-write echoes are naturally
    /// idempotent: a reaction echo lands on state the optimistic update
    /// already applied, and a comment echo is the *only* place a posted
    /// comment gets appended at all (see `postComment`).
    @MainActor
    private func subscribeRealtime() {
        let channel = SupabaseService.shared.channel("post-detail-\(sessionId.uuidString)")

        let reactionInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "reactions", filter: .eq("session_id", value: sessionId))
        let reactionDeletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "reactions", filter: .eq("session_id", value: sessionId))
        let commentInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "comments", filter: .eq("session_id", value: sessionId))

        Task {
            try? await channel.subscribeWithError()
            realtimeChannel = channel

            Task { [weak self] in
                for await insertion in reactionInserts {
                    guard let self, let reaction = try? insertion.decodeRecord(as: Reaction.self, decoder: AnyJSON.decoder) else { continue }
                    guard reaction.userId != self.ownUserId else { continue } // already applied optimistically
                    self.applyReactionChange(kind: reaction.kind, userId: reaction.userId, isInsert: true)
                }
            }
            Task { [weak self] in
                for await deletion in reactionDeletes {
                    guard let self, let reaction = try? deletion.decodeOldRecord(as: Reaction.self, decoder: AnyJSON.decoder) else { continue }
                    guard reaction.userId != self.ownUserId else { continue }
                    self.applyReactionChange(kind: reaction.kind, userId: reaction.userId, isInsert: false)
                }
            }
            Task { [weak self] in
                for await insertion in commentInserts {
                    guard let self, let comment = try? insertion.decodeRecord(as: Comment.self, decoder: AnyJSON.decoder) else { continue }
                    guard !self.comments.contains(where: { $0.id == comment.id }) else { continue }
                    let authorName: String
                    if comment.userId == self.author?.id {
                        authorName = self.author?.displayName ?? "Someone"
                    } else if let profile: Profile = try? await SupabaseService.shared.from("profiles").select().eq("id", value: comment.userId).single().execute().value {
                        authorName = profile.displayName
                    } else {
                        authorName = "Someone"
                    }
                    self.appendComment(CommentDisplay(id: comment.id, authorId: comment.userId, authorName: authorName, body: comment.body, createdAt: comment.createdAt))
                }
            }
        }
    }

    @MainActor
    private func appendComment(_ comment: CommentDisplay) {
        guard !comments.contains(where: { $0.id == comment.id }) else { return }
        comments.append(comment)
    }
}
