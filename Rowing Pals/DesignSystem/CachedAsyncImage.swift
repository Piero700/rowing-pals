//
//  CachedAsyncImage.swift
//  Rowing Pals
//

import SwiftUI

/// An in-memory image cache keyed by URL string, checked synchronously
/// before any network request. Plain `AsyncImage` re-fetches from scratch
/// whenever SwiftUI recreates its view instance — routine in a `LazyVStack`
/// once a card scrolls off-screen and back — which is exactly the
/// flicker-on-scroll `CachedAsyncImage` below exists to avoid.
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    private init() {}

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Like `AsyncImage`, but a cache hit renders instantly with no placeholder
/// flash — the cache lookup is the first thing the task body does, ahead of
/// any suspension point.
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
        let key = url.absoluteString

        if let cached = ImageCache.shared.image(for: key) {
            image = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let downloaded = UIImage(data: data) else { return }
            ImageCache.shared.set(downloaded, for: key)
            guard !Task.isCancelled else { return }
            image = downloaded
        } catch {
            // Leaves the placeholder showing — a failed fetch (expired
            // signed URL, offline) isn't worth surfacing as an error here.
        }
    }
}
