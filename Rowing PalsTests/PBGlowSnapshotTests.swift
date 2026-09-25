//
//  PBGlowSnapshotTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Renders the new-PB glow on a stand-in card to a PNG so it can be looked at without needing a
/// real PB post. Writes to $TMPDIR/pbglow.png and checks the render produced an image.
@MainActor
struct PBGlowSnapshotTests {
    @Test func glowRenders() throws {
        let card = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        let view = VStack(spacing: 40) {
            Text("With glow").foregroundStyle(.white)
                .frame(width: 330, height: 200)
                .background(card.fill(Tokens.Surface.card))
                .pbGlow(true, in: card)
            Text("Without").foregroundStyle(.white)
                .frame(width: 330, height: 200)
                .background(card.fill(Tokens.Surface.card))
                .pbGlow(false, in: card)
        }
        .padding(40)
        .background(Tokens.Base.dark)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        let data = try #require(image.pngData())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pbglow.png")
        try data.write(to: url)
        print("PB glow snapshot: \(url.path)")
        #expect(image.size.width > 0)
    }
}
