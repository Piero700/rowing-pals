//
//  ShareCardTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// The share-workout image (phase J): rendered off screen at a fixed 1080 × 1350 px, with or
/// without a photo, so it posts the same everywhere.
@MainActor
struct ShareCardTests {
    private func render(photo: UIImage?) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(
            photo: photo,
            name: "Joe Bloggs",
            detail: "2k test · 5 Oct 2026",
            distance: "2,000m",
            time: "7:04.1",
            split: "1:46.0"
        ))
        renderer.scale = 3
        return renderer.uiImage
    }

    @Test func rendersAtTheSharedImageSize() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let image = try #require(render(photo: photo))
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1350)
    }

    @Test func rendersWithoutAPhoto() throws {
        let image = try #require(render(photo: nil))
        #expect(image.size.width * image.scale == 1080)
    }
}
