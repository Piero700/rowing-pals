//
//  SwitchVersionRowSnapshotTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Switch to coaching (rower Settings) and Switch to rowing (coach Profile) are one row
/// (user, 2026-10-18). Writes $TMPDIR/switch-rows-dark.png.
@MainActor
struct SwitchVersionRowSnapshotTests {
    @Test func bothSwitchesAreTheSameRow() throws {
        let view = VStack(spacing: Tokens.Spacing.loose) {
            SwitchVersionRow(toCoaching: true) {}
            SwitchVersionRow(toCoaching: false) {}
        }
        .padding(Tokens.Spacing.screen)
        .frame(width: 393)
        .background(Tokens.Base.ground)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try #require(renderer.uiImage)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("switch-rows-dark.png")
        try #require(image.pngData()).write(to: url)
        print("Switch rows: \(url.path)")
    }
}
