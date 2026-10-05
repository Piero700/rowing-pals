//
//  AvatarService.swift
//  Rowing Pals
//

import Foundation
import Supabase
import UIKit

/// Changing the signed-in rower's profile picture (decision 29). The picture is squared, shrunk,
/// checked like any posted photo, uploaded under a fresh name to their own folder in the
/// `avatars` bucket (docs/migrations/2026-10-05-seconds-tests-and-avatars.sql), and
/// `profiles.avatar_path` points at it; the old file is then removed. Every avatar in the app
/// picks the change up through `AvatarStore`.
enum AvatarService {
    enum Failure: LocalizedError {
        case blocked
        case unreadable

        var errorDescription: String? {
            switch self {
            case .blocked: "This photo can't be used as a profile picture."
            case .unreadable: "That photo couldn't be read. Try another."
            }
        }
    }

    /// The longest side of a stored picture, in pixels — sharp at the largest avatar (76 pt at 3×).
    static let side: CGFloat = 600

    static func setPicture(_ image: UIImage) async throws {
        if await ImageModerationService.check(image) == .blocked { throw Failure.blocked }
        guard let data = squareJPEG(image) else { throw Failure.unreadable }

        let userId = try await SupabaseService.shared.auth.session.user.id
        let folder = userId.uuidString.lowercased()
        let old = try await currentPath(userId)
        // A new name each time, so no one is shown a stale copy of the old picture.
        let path = "\(folder)/avatar-\(Int(Date().timeIntervalSince1970)).jpg"
        try await SupabaseService.shared.storage
            .from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        try await setPath(path, for: userId)
        if let old, old != path {
            _ = try? await SupabaseService.shared.storage.from("avatars").remove(paths: [old])
        }
        await AvatarStore.shared.refresh(userId)
    }

    static func removePicture() async throws {
        let userId = try await SupabaseService.shared.auth.session.user.id
        let old = try await currentPath(userId)
        try await setPath(nil, for: userId)
        if let old {
            _ = try? await SupabaseService.shared.storage.from("avatars").remove(paths: [old])
        }
        await AvatarStore.shared.refresh(userId)
    }

    /// The middle square of the photo, at most `side` pixels across, as a JPEG.
    static func squareJPEG(_ image: UIImage) -> Data? {
        let size = image.size
        let edge = min(size.width, size.height)
        guard edge > 0 else { return nil }
        let target = min(edge, side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scale = target / edge
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let squared = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format).image { _ in
            image.draw(in: CGRect(
                x: (target - drawn.width) / 2,
                y: (target - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height
            ))
        }
        return squared.jpegData(compressionQuality: 0.82)
    }

    private static func currentPath(_ userId: UUID) async throws -> String? {
        struct Row: Decodable {
            let avatarPath: String?
            enum CodingKeys: String, CodingKey { case avatarPath = "avatar_path" }
        }
        let row: Row = try await SupabaseService.shared
            .from("profiles").select("avatar_path").eq("id", value: userId).single().execute().value
        return row.avatarPath
    }

    private static func setPath(_ path: String?, for userId: UUID) async throws {
        struct Change: Encodable {
            let avatarPath: String?
            enum CodingKeys: String, CodingKey { case avatarPath = "avatar_path" }
            // Writes null when removing — the synthesised encoder would leave the key out.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(avatarPath, forKey: .avatarPath)
            }
        }
        try await SupabaseService.shared
            .from("profiles").update(Change(avatarPath: path)).eq("id", value: userId).execute()
    }
}
