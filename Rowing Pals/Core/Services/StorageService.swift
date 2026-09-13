//
//  StorageService.swift
//  Rowing Pals
//

import Foundation
import Supabase

enum StorageService {
    /// Uploads JPEG data for one session's photo — `monitors` for the rear
    /// shot, `selfies` for the front one — at `userID/sessionID.jpg`. Naming
    /// both buckets' files after the session's own id is what lets "both
    /// paths reference one row" (per task 08) without a schema change —
    /// `sessions` has no photo-path columns; those live on `segments`
    /// (task 10).
    static func uploadSessionPhoto(_ data: Data, bucket: String, userId: UUID, sessionId: UUID) async throws {
        // Swift's UUID.uuidString is uppercase; Postgres's auth.uid()::text
        // is lowercase. The storage RLS policies compare them as exact
        // strings, so an uppercase path can never match theirs.
        let path = "\(userId.uuidString.lowercased())/\(sessionId.uuidString.lowercased()).jpg"
        try await SupabaseService.shared.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
    }
}
