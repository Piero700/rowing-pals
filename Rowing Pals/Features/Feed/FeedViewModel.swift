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

    /// Everyone blocked in either direction — resolved once and reused for
    /// the life of this view model, since a block only ever happens from
    /// `PostDetailView`, never mid-scroll of the feed itself.
    private var blockedUserIds: [UUID]?

    /// Cached the same way as `blockedUserIds`, for the same reason — see
    /// `resolvedVisibilityFilter()`.
    private var clubmateIds: [UUID]?
    private var followedIds: [UUID]?

    @MainActor
    func loadInitial() async {
        guard posts.isEmpty else { return }
        await reload()
    }

    /// Who is viewing and which club they belong to — loaded once.
    @MainActor
    private func loadViewer() async {
        guard viewerId == nil, let id = try? await SupabaseService.shared.auth.session.user.id else { return }
        viewerId = id
        struct Row: Decodable {
            struct Club: Decodable { let name: String }
            let club: Club?
            enum CodingKeys: String, CodingKey { case club = "clubs" }
        }
        let row: Row? = try? await SupabaseService.shared
            .from("profiles")
            .select("clubs(name)")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        viewerClubName = row?.club?.name
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
        defer { isLoading = false }
        await loadPage(offset: 0, replacing: true)
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
        await loadViewer()
        do {
            var query = SupabaseService.shared
                .from("sessions")
                .select(Self.selectColumns)

            let userIds = try await scope.userIds()
            guard !userIds.isEmpty else {
                if replacing { posts = [] }
                hasMorePages = false
                errorMessage = nil
                return
            }
            query = query.in("user_id", values: userIds)

            let blocked = await resolvedBlockedUserIds()
            if !blocked.isEmpty {
                query = query.notIn("user_id", values: blocked)
            }

            if let visibilityFilter = await resolvedVisibilityFilter() {
                query = query.or(visibilityFilter)
            }

            let page: [FeedPost] = try await query
                .order("posted_at", ascending: false)
                .range(from: offset, to: offset + Self.pageSize - 1)
                .execute()
                .value

            posts = replacing ? page : posts + page
            hasMorePages = page.count == Self.pageSize
            errorMessage = nil
            await fetchSignedURLs(for: page)
            await fetchStreaks(for: page)
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

    /// Filtering, task 17 — blocking works both ways: rows the viewer
    /// blocked, and rows blocked *by* someone whose posts would otherwise
    /// show the viewer as an author. `sessions`' own RLS policy is
    /// `read_all using (true)` (docs/schema.sql) — it doesn't know about
    /// blocks at all, so this client-side filter is the only thing
    /// enforcing it, not a belt-and-braces extra.
    @MainActor
    private func resolvedBlockedUserIds() async -> [UUID] {
        if let blockedUserIds { return blockedUserIds }
        guard let userId = try? await SupabaseService.shared.auth.session.user.id else { return [] }
        struct BlockedByMe: Decodable { let blockedId: UUID
            enum CodingKeys: String, CodingKey { case blockedId = "blocked_id" }
        }
        struct BlockedMe: Decodable { let blockerId: UUID
            enum CodingKeys: String, CodingKey { case blockerId = "blocker_id" }
        }
        async let byMe: [BlockedByMe] = (try? await SupabaseService.shared
            .from("blocks")
            .select("blocked_id")
            .eq("blocker_id", value: userId)
            .execute()
            .value) ?? []
        async let ofMe: [BlockedMe] = (try? await SupabaseService.shared
            .from("blocks")
            .select("blocker_id")
            .eq("blocked_id", value: userId)
            .execute()
            .value) ?? []
        let resolved = Array(Set(await byMe.map(\.blockedId) + (await ofMe.map(\.blockerId))))
        blockedUserIds = resolved
        return resolved
    }

    /// The poster's own audience choice at post time — independent of, and
    /// ANDed with, the viewer's own scope tab above. A 'club'-restricted
    /// post from someone the viewer follows still shouldn't show up in the
    /// Following tab if the viewer isn't actually in that club; every tab
    /// has to honour every post's own restriction, not just its own. Same
    /// "no RLS, filter in the query" approach as `resolvedBlockedUserIds()`,
    /// for the same reason (see the NOTE in docs/schema.sql).
    ///
    /// No app-wide public case (`PostVisibility`, `SocialScope`) — just
    /// club, following, their union ("everyone" — clubmates OR followers,
    /// not every app user), and "it's your own post."
    ///
    /// Returns the raw `.or()` filter string PostgREST expects, or nil if
    /// the viewer can't be identified (session lost) — in that case the
    /// query just runs unfiltered by visibility, same fail-open posture as
    /// `resolvedBlockedUserIds()` returning `[]`.
    @MainActor
    private func resolvedVisibilityFilter() async -> String? {
        guard let userId = try? await SupabaseService.shared.auth.session.user.id else { return nil }

        if clubmateIds == nil {
            clubmateIds = (try? await SocialScope.myClub.userIds()) ?? []
        }
        if followedIds == nil {
            followedIds = (try? await SocialScope.following.userIds()) ?? []
        }
        let clubmateCSV = clubmateIds.flatMap { $0.isEmpty ? nil : $0.map { $0.uuidString.lowercased() }.joined(separator: ",") }
        let followedCSV = followedIds.flatMap { $0.isEmpty ? nil : $0.map { $0.uuidString.lowercased() }.joined(separator: ",") }

        var clauses = ["user_id.eq.\(userId.uuidString.lowercased())"]
        if let clubmateCSV {
            clauses.append("and(visibility.eq.club,user_id.in.(\(clubmateCSV)))")
        }
        if let followedCSV {
            clauses.append("and(visibility.eq.following,user_id.in.(\(followedCSV)))")
        }
        switch (clubmateCSV, followedCSV) {
        case (nil, nil):
            break
        case (let club?, nil):
            clauses.append("and(visibility.eq.everyone,user_id.in.(\(club)))")
        case (nil, let following?):
            clauses.append("and(visibility.eq.everyone,user_id.in.(\(following)))")
        case (let club?, let following?):
            clauses.append("and(visibility.eq.everyone,or(user_id.in.(\(club)),user_id.in.(\(following))))")
        }
        return clauses.joined(separator: ",")
    }

    /// The selfie's storage path is never stored in the DB — it's always at
    /// this convention-based path (task 08/10) — so it's derived here
    /// rather than read off `FeedPost`.
    static func selfiePath(userId: UUID, sessionId: UUID) -> String {
        "\(userId.uuidString.lowercased())/\(sessionId.uuidString.lowercased()).jpg"
    }
}
