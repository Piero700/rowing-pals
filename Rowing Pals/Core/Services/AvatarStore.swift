//
//  AvatarStore.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Profile pictures (decision 29) for any rower, by id, for every avatar in the app. Avatars ask
/// as they appear; the asks made together go to the server as one: one `profiles` read for the
/// paths, then one batch of signed links from the private `avatars` bucket. A rower with no
/// picture — or one this viewer may not see (a private account they don't follow) — has no link,
/// and their avatar keeps its initials.
@MainActor
@Observable
final class AvatarStore {
    static let shared = AvatarStore()

    /// A signed link per rower with a visible picture.
    private(set) var urls: [UUID: URL] = [:]

    @ObservationIgnored private var fetchedAt: [UUID: Date] = [:]
    @ObservationIgnored private var pending: Set<UUID> = []
    @ObservationIgnored private var flushTask: Task<Void, Never>?

    /// Links are signed for an hour; fetch again a little before they lapse.
    private static let lifetime: TimeInterval = 50 * 60
    /// "No picture" is checked again sooner, so a newly added one shows within a minute.
    private static let missingLifetime: TimeInterval = 60

    func url(for userId: UUID) -> URL? { urls[userId] }

    /// Asks for a rower's picture, unless it was fetched recently.
    func load(_ userId: UUID) {
        let lifetime = urls[userId] == nil ? Self.missingLifetime : Self.lifetime
        if let at = fetchedAt[userId], Date().timeIntervalSince(at) < lifetime { return }
        pending.insert(userId)
        guard flushTask == nil else { return }
        flushTask = Task {
            // Gathers the other avatars appearing in the same moment into one request.
            try? await Task.sleep(for: .milliseconds(40))
            await flush()
        }
    }

    /// A link that no longer loads — its owner replaced or removed the picture. Fetches the
    /// current one, at most once a minute per rower.
    func linkFailed(_ userId: UUID) {
        if let at = fetchedAt[userId], Date().timeIntervalSince(at) < Self.missingLifetime { return }
        refresh(userId)
    }

    /// Fetches a rower's picture again — after they change or remove it.
    func refresh(_ userId: UUID) {
        fetchedAt[userId] = nil
        load(userId)
    }

    private func flush() async {
        let ids = Array(pending)
        pending.removeAll()
        flushTask = nil
        guard !ids.isEmpty else { return }
        let now = Date()
        for id in ids { fetchedAt[id] = now }

        struct Row: Decodable {
            let id: UUID
            let avatarPath: String?
            enum CodingKeys: String, CodingKey {
                case id
                case avatarPath = "avatar_path"
            }
        }
        guard let rows: [Row] = try? await SupabaseService.shared
            .from("profiles").select("id, avatar_path").in("id", values: ids).execute().value
        else {
            // Try again next time they appear.
            for id in ids { fetchedAt[id] = nil }
            return
        }

        var idByPath: [String: UUID] = [:]
        for row in rows {
            if let path = row.avatarPath {
                idByPath[path] = row.id
            } else {
                urls[row.id] = nil
            }
        }
        guard !idByPath.isEmpty else { return }
        let results = (try? await SupabaseService.shared.storage
            .from("avatars").createSignedURLs(paths: Array(idByPath.keys), expiresIn: 3600)) ?? []
        for result in results {
            switch result {
            case .success(let path, let signedURL):
                if let id = idByPath[path] { urls[id] = signedURL }
            case .failure(let path, _):
                // Not visible to this viewer, or gone.
                if let id = idByPath[path] { urls[id] = nil }
            }
        }
    }
}
