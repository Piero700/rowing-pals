//
//  ShareWeekCardTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// The week / workout share picture (decision 110): fixed 1080 px width, grows with its rows,
/// always dark.
@MainActor
struct ShareWeekCardTests {
    private func rows(_ count: Int, titleLength: Int = 10) -> [ShareCardRow] {
        (0..<count).map {
            ShareCardRow(id: "r\($0)", start: .distantPast, dayText: "Tue", timeText: "06:30",
                         title: String(repeating: "x", count: titleLength), detail: "Boathouse")
        }
    }

    private func render(_ rows: [ShareCardRow]) -> UIImage? {
        let renderer = ImageRenderer(content: ShareWeekCardView(
            heading: "This week", subheading: "Novice men · 23–29 Nov", rows: rows)
            .environment(\.colorScheme, .light))
        renderer.scale = 3
        return renderer.uiImage
    }

    @Test func rendersAtSharedWidth() throws {
        let image = try #require(render(rows(3)))
        #expect(image.size.width * image.scale == 1080)
    }

    @Test func busyWeekGrowsTaller() throws {
        let short = try #require(render(rows(3)))
        let busy = try #require(render(rows(12, titleLength: 60)))
        #expect(busy.size.height > short.size.height)
        #expect(busy.size.width * busy.scale == 1080)
    }

    @Test func emptyWeekStillRenders() throws {
        #expect(render([]) != nil)
    }

    @Test func alwaysDark() throws {
        let image = try #require(render(rows(3)))
        let cg = try #require(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
                                             bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // Bitmap origin is bottom-left: shift the image up so its top-left pixel lands in the 1x1 context.
        context.draw(cg, in: CGRect(x: 0, y: 1 - cg.height, width: cg.width, height: cg.height))
        #expect(abs(Int(pixel[0]) - 0x10) <= 1)
        #expect(abs(Int(pixel[1]) - 0x11) <= 1)
        #expect(abs(Int(pixel[2]) - 0x14) <= 1)
    }
}
