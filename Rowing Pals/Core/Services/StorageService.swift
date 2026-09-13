//
//  StorageService.swift
//  Rowing Pals
//

import Foundation
import Supabase

enum StorageService {
    /// Uploads JPEG data to the `monitors` bucket at `userID/UUID.jpg` and
    /// returns that path — callers store the path on the row, not a URL.
    static func uploadMonitorPhoto(_ data: Data, userId: UUID) async throws -> String {
        // Swift's UUID.uuidString is uppercase; Postgres's auth.uid()::text
        // is lowercase. The storage RLS policy compares them as exact
        // strings, so an uppercase path can never match — lowercase both
        // segments to actually satisfy it.
        let path = "\(userId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await SupabaseService.shared.storage
            .from("monitors")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        return path
    }
}
