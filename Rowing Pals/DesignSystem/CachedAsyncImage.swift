//
//  CachedAsyncImage.swift
//  Rowing Pals
//

import CryptoKit
import SwiftUI

/// Photos kept in memory and on disk, so a photo already seen shows at once — after a refresh,
/// on another screen, or after relaunching the app.
///
/// Keyed by the stored file, not the link: a private photo's signed link carries a new token
/// every time it's issued, so keying by the whole link missed the cache on every refresh and
/// downloaded every photo again. Every stored file is written once and never changed (profile
/// pictures get a new name each time), so a file's photo can be kept for good. The disk copy
/// lives in Caches, which iOS clears when space is short.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    private init() {}

    /// The stored file for a Supabase Storage link (bucket and path, without the token);
    /// any other link as it is.
    nonisolated static func key(for url: URL) -> String {
        if url.path.contains("/storage/v1/object/") {
            return (url.host ?? "") + url.path
        }
        return url.absoluteString
    }

    func image(for key: String) -> UIImage? {
        memory.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        memory.setObject(image, forKey: key as NSString)
    }

    // MARK: - Disk

    private nonisolated static let directory: URL? = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = caches.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private nonisolated static func fileURL(for key: String) -> URL? {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory?.appendingPathComponent(digest)
    }

    /// The photo from disk, decoded off the main thread; nil if it isn't there.
    nonisolated static func diskImage(for key: String) async -> UIImage? {
        guard let url = fileURL(for: key) else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
            return await image.byPreparingForDisplay() ?? image
        }.value
    }

    nonisolated static func storeOnDisk(_ data: Data, for key: String) {
        guard let url = fileURL(for: key) else { return }
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Decodes downloaded bytes into a photo ready to draw, off the main thread, so scrolling
    /// past a new photo doesn't stall while it's unpacked.
    nonisolated static func decode(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let image = UIImage(data: data) else { return nil }
            return await image.byPreparingForDisplay() ?? image
        }.value
    }

    /// Memory, then disk, then the network; whatever is fetched is kept in both.
    func load(_ url: URL) async -> UIImage? {
        let key = Self.key(for: url)
        if let cached = image(for: key) { return cached }
        if let fromDisk = await Self.diskImage(for: key) {
            set(fromDisk, for: key)
            return fromDisk
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let downloaded = await Self.decode(data) else { return nil }
        set(downloaded, for: key)
        Self.storeOnDisk(data, for: key)
        return downloaded
    }
}

/// Like `AsyncImage`, but a photo already in memory renders instantly with no placeholder
/// flash — the memory lookup happens before any suspension point — and one on disk or the
/// network is prepared off the main thread.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else { image = nil; return }
        if let cached = ImageCache.shared.image(for: ImageCache.key(for: url)) {
            image = cached
            return
        }
        // A failed fetch (expired link, offline) leaves the placeholder showing.
        guard let loaded = await ImageCache.shared.load(url), !Task.isCancelled else { return }
        image = loaded
    }
}
