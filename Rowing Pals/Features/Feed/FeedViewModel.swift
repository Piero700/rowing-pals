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
    enum Scope: Int, CaseIterable {
        case following, myClub, global

        var label: String {
            switch self {
            case .following: "Following"
            case .myClub: "My Club"
            case .global: "Global"
            }
        }
    }

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

    var scope: Scope = .global {
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

            if let userIds = try await userIds(forScope: scope) {
                guard !userIds.isEmpty else {
                    if replacing { posts = [] }
                    hasMorePages = false
                    errorMessage = nil
                    return
                }
                query = query.in("user_id", values: userIds)
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

    /// nil means "no scope filter" (Global). Following/My Club resolve to a
    /// concrete, possibly-empty list of user ids first — PostgREST filters
    /// the base table by a column on an embedded relation awkwardly, but
    /// filtering `sessions.user_id` by a plain id list is exactly what the
    /// existing typed query builder already does well.
    private func userIds(forScope scope: Scope) async throws -> [UUID]? {
        switch scope {
        case .global:
            return nil

        case .following:
            let userId = try await SupabaseService.shared.auth.session.user.id
            struct Row: Decodable { let followeeId: UUID
                enum CodingKeys: String, CodingKey { case followeeId = "followee_id" }
            }
            let rows: [Row] = try await SupabaseService.shared
                .from("follows")
                .select("followee_id")
                .eq("follower_id", value: userId)
                .execute()
                .value
            return rows.map(\.followeeId)

        case .myClub:
            let userId = try await SupabaseService.shared.auth.session.user.id
            let profile: Profile = try await SupabaseService.shared
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            guard let clubId = profile.clubId else { return [] }
            struct Row: Decodable { let id: UUID }
            let rows: [Row] = try await SupabaseService.shared
                .from("profiles")
                .select("id")
                .eq("club_id", value: clubId)
                .execute()
                .value
            return rows.map(\.id)
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

    /// The selfie's storage path is never stored in the DB — it's always at
    /// this convention-based path (task 08/10) — so it's derived here
    /// rather than read off `FeedPost`.
    static func selfiePath(userId: UUID, sessionId: UUID) -> String {
        "\(userId.uuidString.lowercased())/\(sessionId.uuidString.lowercased()).jpg"
    }
}
