//
//  FeedViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns the feed's paginated `sessions` query, its Following/My Club/Global
/// scope, and the signed URLs for every post's photos.
@Observable
final class FeedViewModel {
    private static let pageSize = 20
    /// One request, shared by every embedded relation this query needs —
    /// PostgREST returns nested resources with their parent, not as
    /// separate round trips.
    private static let selectColumns = """
    id, user_id, type, caption, total_distance_m, total_time_ms, avg_split_ms, avg_rate, \
    photo_verified, logged_late, posted_at, \
    profiles!sessions_user_id_fkey(display_name, category, gender, avatar_path, clubs(name)), \
    segments(id, label, position, distance_m, monitor_photo_path)
    """

    var scope: SocialScope = .global {
        didSet {
            guard oldValue != scope else { return }
            Task { await reload() }
        }
    }

    var posts: [FeedPost] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    /// Storage path → signed URL, reused across scrolling and re-renders so
    /// the same photo is never handed a second, different signed URL —
    /// `CachedAsyncImage` caches by URL string, so a fresh URL for a photo
    /// it already has would defeat that cache and refetch for nothing.
    private var signedURLs: [String: URL] = [:]
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

    @MainActor
    private func loadPage(offset: Int, replacing: Bool) async {
        do {
            var query = SupabaseService.shared
                .from("sessions")
                .select(Self.selectColumns)

            if let userIds = try await scope.userIds() {
                guard !userIds.isEmpty else {
                    if replacing { posts = [] }
                    hasMorePages = false
                    errorMessage = nil
                    return
                }
                query = query.in("user_id", values: userIds)
            }

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
        let monitorPaths: [String] = page.compactMap { post in
            guard let path = post.primarySegment?.monitorPhotoPath, signedURLs[path] == nil else { return nil }
            return path
        }
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

    /// The poster's own audience choice at post time (new feature, built
    /// after task 18) — independent of, and ANDed with, the viewer's own
    /// scope tab above. A 'club'-restricted post from someone the viewer
    /// follows still shouldn't show up in the Following tab if the viewer
    /// isn't actually in that club; every tab has to honour every post's
    /// own restriction, not just its own. Same "no RLS, filter in the
    /// query" approach as `resolvedBlockedUserIds()`, for the same reason
    /// (see the NOTE in docs/schema.sql).
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

        var clauses = ["visibility.eq.global", "user_id.eq.\(userId.uuidString.lowercased())"]
        if let clubmateIds, !clubmateIds.isEmpty {
            let csv = clubmateIds.map { $0.uuidString.lowercased() }.joined(separator: ",")
            clauses.append("and(visibility.eq.club,user_id.in.(\(csv)))")
        }
        if let followedIds, !followedIds.isEmpty {
            let csv = followedIds.map { $0.uuidString.lowercased() }.joined(separator: ",")
            clauses.append("and(visibility.eq.following,user_id.in.(\(csv)))")
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
