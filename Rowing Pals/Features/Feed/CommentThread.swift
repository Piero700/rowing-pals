//
//  CommentThread.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// One post's comments: loaded in order, written, reported, and kept live via Realtime. The
/// workout screen's inline comments and the full-screen thread share one instance when the
/// thread is opened from the workout, so a comment written in either shows in both.
@Observable
final class CommentThread {
    struct Entry: Identifiable {
        let id: UUID
        let authorId: UUID
        let authorName: String
        let body: String
        let createdAt: Date
    }

    let sessionId: UUID
    var comments: [Entry] = []
    var isLoading = false
    var hasLoaded = false
    /// Load failures and refused comments, shown above the composer.
    var errorMessage: String?

    /// Postgres's "insufficient privilege": a row-level security rule refused the write.
    private static let notAllowedCode = "42501"
    static let notAllowedMessage = "Only people who follow this rower or share their club can comment."

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
            async let list = Self.loadComments(sessionId: sessionId)
            async let name = Self.fetchDisplayName(userId: userId)
            let (loaded, ownName) = try await (list, name)
            // A comment that arrived live while loading is kept.
            let loadedIds = Set(loaded.map(\.id))
            comments = loaded + comments.filter { !loadedIds.contains($0.id) }
            ownDisplayName = ownName
            hasLoaded = true
            errorMessage = nil
            if realtimeChannel == nil { subscribeRealtime() }
        } catch {
            print("Comments load failed (\(sessionId)): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        guard let realtimeChannel else { return }
        self.realtimeChannel = nil
        Task { await SupabaseService.shared.removeChannel(realtimeChannel) }
    }

    @MainActor
    func isOwnComment(_ comment: Entry) -> Bool {
        comment.authorId == ownUserId
    }

    // MARK: - Writing

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
            // Appended locally straight away: the Realtime echo of this client's own write
            // doesn't reliably arrive (found on a real device). `append` drops a duplicate
            // if it does.
            append(Entry(id: newComment.id, authorId: userId, authorName: ownDisplayName, body: trimmed, createdAt: newComment.createdAt))
            errorMessage = nil
        } catch let error as PostgrestError where error.code == Self.notAllowedCode {
            // The database's own rule (decision 33): only people who can see a post may comment,
            // e.g. this rower unfollowed the author, or the author changed who can see it.
            print("Comment refused (\(sessionId)): \(error)")
            errorMessage = Self.notAllowedMessage
        } catch {
            errorMessage = error.localizedDescription
        }
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

    // MARK: - Loading

    private static func loadComments(sessionId: UUID) async throws -> [Entry] {
        struct Row: Decodable {
            struct Author: Decodable {
                let displayName: String
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
        return rows.map { Entry(id: $0.id, authorId: $0.userId, authorName: $0.author.displayName, body: $0.body, createdAt: $0.createdAt) }
    }

    private static func fetchDisplayName(userId: UUID) async throws -> String {
        struct Row: Decodable {
            let displayName: String
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

    // MARK: - Realtime

    /// Comments from anyone, including this account on another device, arrive without a
    /// refresh (task 16).
    @MainActor
    private func subscribeRealtime() {
        // Unique per instance: the feed's thread and a workout's thread must never share one.
        let channel = SupabaseService.shared.channel("comments-\(sessionId.uuidString)-\(UUID().uuidString)")
        let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "comments", filter: .eq("session_id", value: sessionId))
        realtimeChannel = channel

        Task {
            try? await channel.subscribeWithError()
            Task { [weak self] in
                for await insertion in inserts {
                    guard let self, let comment = try? insertion.decodeRecord(as: Comment.self, decoder: AnyJSON.decoder) else { continue }
                    guard !self.comments.contains(where: { $0.id == comment.id }) else { continue }
                    let authorName: String
                    if comment.userId == self.ownUserId {
                        authorName = self.ownDisplayName
                    } else if let name = try? await Self.fetchDisplayName(userId: comment.userId) {
                        authorName = name
                    } else {
                        authorName = "Someone"
                    }
                    self.append(Entry(id: comment.id, authorId: comment.userId, authorName: authorName, body: comment.body, createdAt: comment.createdAt))
                }
            }
        }
    }

    @MainActor
    private func append(_ comment: Entry) {
        guard !comments.contains(where: { $0.id == comment.id }) else { return }
        comments.append(comment)
    }
}
