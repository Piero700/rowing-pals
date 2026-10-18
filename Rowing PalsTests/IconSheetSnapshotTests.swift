//
//  IconSheetSnapshotTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Draws every `RPIcon` (decision 80) on one sheet at 20 and 16 pt, to compare with the canvas.
/// Writes $TMPDIR/icons-dark.png and checks every icon has an outline.
@MainActor
struct IconSheetSnapshotTests {
    @Test func everyIconHasAnOutline() {
        for icon in RPIcon.allCases {
            #expect(!icon.outline.isEmpty, "\(icon) has no outline")
            let box = icon.outline.boundingRect
            #expect(box.minX >= 0 && box.minY >= 0 && box.maxX <= 24 && box.maxY <= 24, "\(icon) leaves its 24 grid")
        }
    }

    @Test func iconSheetRenders() throws {
        let columns = Array(repeating: GridItem(.fixed(78), spacing: 6), count: 5)
        let view = LazyVGrid(columns: columns, spacing: 14) {
            ForEach(RPIcon.allCases, id: \.self) { icon in
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        RPIconView(icon: icon)
                        RPIconView(icon: icon, size: Tokens.Icon.small)
                    }
                    Text(icon.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(Tokens.Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(Tokens.Ink.primary)
            }
        }
        .padding(16)
        .frame(width: 440)
        .background(Tokens.Base.ground)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("icons-dark.png")
        try #require(image.pngData()).write(to: url)
        print("Icon sheet: \(url.path)")
    }
}
