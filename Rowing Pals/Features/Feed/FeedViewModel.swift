//
//  FeedViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns the feed's paginated `sessions` query, its Following/My Club
/// scope, and the signed URLs for every post's photos.
@Observable
final class FeedViewModel {
    private static let pageSize = 20
    /// One request, shared by every embedded relation this query needs —
    /// PostgREST returns nested resources with their parent, not as
    /// separate round trips.
    private static let selectColumns = """
    id, user_id, type, caption, workout_label, total_distance_m, total_time_ms, avg_split_ms, avg_rate, \
    photo_verified, logged_late, is_new_pb, posted_at, \
    profiles!sessions_user_id_fkey(display_name, category, gender, avatar_path, clubs(name)), \
    segments(id, label, position, distance_m, time_ms, split_ms, monitor_photo_path, is_lead), \
    session_photos(position, path), \
    reactions(kind, user_id), \
    comments(count)
    """

    var scope: SocialScope = .myClub {
        didSet {
            guard oldValue != scope else { return }
            Task { await reload() }
        }
    }

    var posts: [FeedPost] = []
    /// The signed-in rower — to mark their own reactions and hide Follow on their own posts.
    var viewerId: UUID?
    /// The viewer's club, for the Club tab's caption; nil when they have none.
    var viewerClubName: String?
    /// False for a coach-only account: no "Post a workout" (decision 34).
    var viewerIsRower = true
    /// Posts the viewer sees only as the author's coach: read-only (decision 40).
    var readOnlyPostIds: Set<UUID> = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    /// Storage path → signed URL, reused across scrolling and re-renders so
    /// the same photo is never handed a second, different signed URL —
    /// `CachedAsyncImage` caches by URL string, so a fresh URL for a photo
    /// it already has would defeat that cache and refetch for nothing.
    private var signedURLs: [String: URL] = [:]
    /// Author user_id → current streak length, resolved once per author
    /// encountered across pagination and reused — same caching rationale
    /// as `signedURLs`. Computed client-side via `StreakCalculator` from a
    /// batched `daily_totals` fetch, not one `current_streak(...)` RPC call
    /// per avatar — see `fetchStreaks(for:)`.
    private var streaks: [UUID: Int] = [:]
    private var hasMorePages = true

    @MainActor
    func loadInitial() async {
        guard posts.isEmpty else { return }
        await reload()
    }

    /// A request waiting on a club (decision 26): the Club tab says so instead of "not in a club".
    var pendingClubName: String?

    /// Who is viewing and their club, from the shared viewer context (no request of its own
    /// once that's loaded).
    @MainActor
    private func loadViewer() async {
        guard let viewer = try? await ViewerContext.shared.current() else { return }
        viewerId = viewer.userId
        viewerClubName = viewer.clubName
        viewerIsRower = viewer.isRower
    }

    /// A join request still waiting on a club's answer (decision 26).
    private static func pendingClubName(for userId: UUID) async -> String? {
        struct Pending: Decodable {
            struct Club: Decodable { let name: String }
            let clubs: Club
        }
        let pending: [Pending]? = try? await SupabaseService.shared
            .from("club_join_requests").select("clubs(name)").eq("user_id", value: userId)
            .eq("status", value: "pending").execute().value
        return pending?.first?.clubs.name
    }

    // MARK: - Reactions

    /// The reactions on a post, grouped by kind in picker order, each with its count and
    /// whether the viewer is one of them.
    struct ReactionSummary: Identifiable {
        let kind: String
        let count: Int
        let isMine: Bool
        var id: String { kind }
    }

    func reactionSummaries(for post: FeedPost) -> [ReactionSummary] {
        let grouped = Dictionary(grouping: post.reactions, by: \.kind)
        return grouped
            .map { kind, rows in
                ReactionSummary(kind: kind, count: rows.count, isMine: rows.contains { $0.userId == viewerId })
            }
            .sorted { ReactionCatalog.sortIndex(for: $0.kind) < ReactionCatalog.sortIndex(for: $1.kind) }
    }

    /// A post's comment total after the thread or the workout screen changed it.
    @MainActor
    func setCommentCount(_ count: Int, on postId: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[index].commentCounts = [FeedPost.CountRow(count: count)]
    }

    /// Adds or removes the viewer's reaction of `kind`, showing it at once and undoing it if
    /// the write fails.
    @MainActor
    func toggleReaction(kind: String, on postId: UUID) async {
        guard let viewerId, let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        let mine = FeedPost.ReactionRow(kind: kind, userId: viewerId)
        let wasOn = posts[index].reactions.contains(mine)
        if wasOn {
            posts[index].reactions.removeAll { $0 == mine }
        } else {
            posts[index].reactions.append(mine)
        }
        do {
            if wasOn {
                try await SupabaseService.shared
                    .from("reactions")
                    .delete()
                    .eq("session_id", value: postId)
                    .eq("user_id", value: viewerId)
                    .eq("kind", value: kind)
                    .execute()
            } else {
                try await SupabaseService.shared
                    .from("reactions")
                    .insert(Reaction(sessionId: postId, userId: viewerId, kind: kind, createdAt: Date()))
                    .execute()
            }
        } catch {
            guard let undoIndex = posts.firstIndex(where: { $0.id == postId }) else { return }
            if wasOn {
                posts[undoIndex].reactions.append(mine)
            } else {
                posts[undoIndex].reactions.removeAll { $0 == mine }
            }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func reload() async {
        isLoading = true
        let perf = PerfLog.start()
        defer { isLoading = false; PerfLog.done("Feed", since: perf) }
        await loadPage(offset: 0, replacing: true)
    }

    /// The viewer just joined a club (decision 24): forget the cached club and clubmates, then
    /// load the Club tab afresh.
    @MainActor
    func clubChanged() async {
        viewerId = nil
        viewerClubName = nil
        await reload()
    }

    /// Called as each card appears — loads the next page once the user is
    /// within the last few rows of what's loaded so far.
    @MainActor
    func loadMoreIfNeeded(currentPost: FeedPost) async {
        guard
            let index = posts.firstIndex(where: { $0.id == currentPost.id }),
            index >= posts.count - 5,
            hasMorePages, !isLoadingMore
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        await loadPage(offset: posts.count, replacing: false)
    }

    func signedURL(forPath path: String) -> URL? {
        signedURLs[path]
    }

    /// 0 (no badge) until that author's streak has been resolved by
    /// `fetchStreaks(for:)` — same "batched lookup exposed as a method"
    /// shape as `signedURL(forPath:)`.
    func streakDays(forAuthor userId: UUID) -> Int {
        streaks[userId] ?? 0
    }

    @MainActor
    private func loadPage(offset: Int, replacing: Bool) async {
        // Fresh loads only; the next page of the same feed needs nothing new.
        if offset == 0 || viewerId == nil {
            await loadViewer()
        }
        do {
            // Who's in scope comes from the shared viewer context. Following is "you and people
            // you follow", so it includes the viewer's own posts.
            var userIds = try await scope.userIds()
            if scope == .following, let viewerId, !userIds.contains(viewerId) {
                userIds.append(viewerId)
            }
            guard !userIds.isEmpty else {
                if replacing { posts = [] }
                hasMorePages = false
                errorMessage = nil
                if offset == 0, let viewerId { pendingClubName = await Self.pendingClubName(for: viewerId) }
                return
            }

            // One query for the page. Who may see each post — blocks either way, private
            // accounts, the post's Following / Club / Everyone setting — is the database's job
            // (decision 33's `can_view_session`), so the app doesn't repeat it in the query.
            let scopeIds = userIds
            let viewer = viewerId
            let currentPending = pendingClubName
            async let pageRequest: [FeedPost] = SupabaseService.shared
                .from("sessions")
                .select(Self.selectColumns)
                .in("user_id", values: scopeIds)
                .order("posted_at", ascending: false)
                .range(from: offset, to: offset + Self.pageSize - 1)
                .execute()
                .value
            async let pending: String? = {
                guard offset == 0, let viewer else { return currentPending }
                return await Self.pendingClubName(for: viewer)
            }()
            let (page, pendingName) = try await (pageRequest, pending)

            posts = replacing ? page : posts + page
            let readOnly = await CoachingService.readOnlyPosts(among: page.map(\.id))
            readOnlyPostIds = replacing ? readOnly : readOnlyPostIds.union(readOnly)
            pendingClubName = pendingName
            hasMorePages = page.count == Self.pageSize
            errorMessage = nil
            // Photo links and streak badges don't depend on each other: fetch both at once.
            async let urls: Void = fetchSignedURLs(for: page)
            async let streakBadges: Void = fetchStreaks(for: page)
            _ = await (urls, streakBadges)
        } catch {
            // Per task 12: "Feed blanks after a few pages -> pagination
            // cursor bug; print the query being sent." Printing the actual
            // failure here is that same debugging aid for whatever does go
            // wrong.
            print("Feed query failed (offset \(offset), scope \(scope)): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// Batches every photo path this page needs into one signed-URL request
    /// per bucket, skipping paths already resolved from an earlier page.
    @MainActor
    private func fetchSignedURLs(for page: [FeedPost]) async {
        // `let`, not `var` built up in a loop — captured mutable state in an
        // `async let` initializer is a data-race warning today and a hard
        // error under strict Swift 6 concurrency.
        // Every carousel page: each piece's monitor photo and each environment photo — all
        // live in the `monitors` bucket.
        let monitorPaths: [String] = page
            .flatMap { $0.pages.map(\.path) }
            .filter { signedURLs[$0] == nil }
        let selfiePaths: [String] = page.compactMap { post in
            let path = Self.selfiePath(userId: post.userId, sessionId: post.id)
            return signedURLs[path] == nil ? path : nil
        }

        async let monitors = Self.signURLs(bucket: "monitors", paths: monitorPaths)
        async let selfies = Self.signURLs(bucket: "selfies", paths: selfiePaths)
        for (path, url) in await monitors { signedURLs[path] = url }
        for (path, url) in await selfies { signedURLs[path] = url }
    }

    private static func signURLs(bucket: String, paths: [String]) async -> [(String, URL)] {
        guard !paths.isEmpty else { return [] }
        guard let results = try? await SupabaseService.shared.storage.from(bucket).createSignedURLs(paths: paths, expiresIn: 3600) else {
            return []
        }
        return results.compactMap { result in
            switch result {
            case .success(let path, let signedURL): (path, signedURL)
            case .failure: nil
            }
        }
    }

    /// One batched `daily_totals` fetch for every author on this page whose
    /// streak isn't already cached, then `StreakCalculator.streak(...)`
    /// computes each one client-side — never a `current_streak(...)` RPC
    /// call per avatar (see StreakCalculator's doc comment and
    /// docs/schema.sql's `current_streak`, the source of truth this must
    /// stay in lockstep with). Best-effort: a failure here just leaves
    /// those authors' badges unresolved (streakDays reads back as 0) rather
    /// than failing the whole feed page.
    @MainActor
    private func fetchStreaks(for page: [FeedPost]) async {
        let authorIds = Array(Set(page.map(\.userId).filter { streaks[$0] == nil }))
        guard !authorIds.isEmpty else { return }

        struct Row: Decodable {
            let userId: UUID
            let day: String
            let sessionCount: Int
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case day
                case sessionCount = "session_count"
            }
        }

        guard let rows: [Row] = try? await SupabaseService.shared
            .from("daily_totals")
            .select("user_id, day, session_count")
            .in("user_id", values: authorIds)
            .gte("day", value: StreakCalculator.earliestRelevantDay())
            .execute()
            .value
        else { return }

        var activeDaysByUser: [UUID: Set<String>] = [:]
        for row in rows where row.sessionCount > 0 {
            activeDaysByUser[row.userId, default: []].insert(row.day)
        }
        for authorId in authorIds {
            streaks[authorId] = StreakCalculator.streak(activeDays: activeDaysByUser[authorId] ?? [])
        }
    }



    /// The selfie's storage path is never stored in the DB — it's always at
    /// this convention-based path (task 08/10) — so it's derived here
    /// rather than read off `FeedPost`.
    static func selfiePath(userId: UUID, sessionId: UUID) -> String {
        "\(userId.uuidString.lowercased())/\(sessionId.uuidString.lowercased()).jpg"
    }
}
