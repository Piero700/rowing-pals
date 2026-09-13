//
//  StorageService.swift
//  Rowing Pals
//

import Foundation
import Supabase

enum StorageService {
    /// Uploads JPEG data for a session's one-per-session photo — the
    /// `selfies` front shot — at `userID/sessionID.jpg`. A session has
    /// exactly one selfie no matter how many monitor photos it has (task
    /// 10 adds multiple), so it doesn't need a position in its path.
    static func uploadSessionPhoto(_ data: Data, bucket: String, userId: UUID, sessionId: UUID) async throws {
        // Swift's UUID.uuidString is uppercase; Postgres's auth.uid()::text
        // is lowercase. The storage RLS policies compare them as exact
        // strings, so an uppercase path can never match theirs.
        let path = "\(userId.uuidString.lowercased())/\(sessionId.uuidString.lowercased()).jpg"
        try await SupabaseService.shared.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
    }

    /// Uploads one segment's monitor photo to `monitors`, nested under the
    /// session by its position — a session can have several (task 10's
    /// "+ Add another photo"), so unlike the selfie these can't share a bare
    /// `sessionID.jpg` path. Returns the path to store on the segment's
    /// `monitor_photo_path` column.
    static func uploadSegmentPhoto(_ data: Data, userId: UUID, sessionId: UUID, position: Int) async throws -> String {
        let path = "\(userId.uuidString.lowercased())/\(sessionId.uuidString.lowercased())/\(position).jpg"
        try await SupabaseService.shared.storage
            .from("monitors")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        return path
    }
}
