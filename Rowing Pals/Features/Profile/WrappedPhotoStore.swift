//
//  WrappedPhotoStore.swift
//  Rowing Pals
//

import UIKit

/// The photos a rower picks for their Season Wrapped pages, kept on this phone (user, 2026-11-03:
/// "remember the Wrapped photos when I leave the screen"): one JPEG per page of each season, under
/// Application Support so iOS doesn't clear them, and kept apart for each account on the phone.
nonisolated enum WrappedPhotoStore {
    /// Every page's photo for this rower's season.
    static func photos(user: UUID, period: String) -> [WrappedPage: UIImage] {
        var result: [WrappedPage: UIImage] = [:]
        for page in WrappedPage.allCases {
            guard let url = url(user: user, period: period, page: page),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { continue }
            result[page] = image
        }
        return result
    }

    /// Keeps the page's photo, or forgets it when `image` is nil.
    static func save(_ image: UIImage?, user: UUID, period: String, page: WrappedPage) {
        guard let url = url(user: user, period: period, page: page) else { return }
        guard let image, let data = image.jpegData(compressionQuality: 0.85) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// …/Application Support/WrappedPhotos/<user>/<season>-<page>.jpg
    private static func url(user: UUID, period: String, page: WrappedPage) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let name = "\(period)-\(page.rawValue).jpg".replacingOccurrences(of: "/", with: "_")
        return base.appendingPathComponent("WrappedPhotos", isDirectory: true)
            .appendingPathComponent(user.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(name)
    }
}
