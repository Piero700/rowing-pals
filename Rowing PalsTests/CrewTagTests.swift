//
//  CrewTagTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Crew tagging (decision 90): a tag as PostgREST returns it, first names, and the "with …" line
/// rendered for a look at it ($TMPDIR/crew-tags.png).
@MainActor
struct CrewTagTests {
    @Test func decodesATagWithItsName() throws {
        let json = """
        [{"session_id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","user_id":"7F9619FF-8B86-D011-B42D-00C04FC964FF",
          "profiles":{"display_name":"Sam Cole"}},
         {"session_id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","user_id":"8F9619FF-8B86-D011-B42D-00C04FC964FF",
          "profiles":null}]
        """
        let tags = try JSONDecoder().decode([SessionTag].self, from: Data(json.utf8))
        #expect(tags.map(\.displayName) == ["Sam Cole", "A rower"])
        #expect(SessionTag.firstName(tags[0].displayName) == "Sam")
        #expect(SessionTag.firstName("Priya") == "Priya")
    }

    @Test func theWithLineRenders() throws {
        let session = UUID()
        func tags(_ names: [String]) -> [SessionTag] {
            names.map { SessionTag(sessionId: session, userId: UUID(), displayName: $0) }
        }
        let view = VStack(alignment: .leading, spacing: 10) {
            TrainedWithLine(tags: tags(["Sam Cole"]), onOpen: { _ in })
            TrainedWithLine(tags: tags(["Sam Cole", "Joe Fenwick"]), onOpen: { _ in })
            TrainedWithLine(tags: tags(["Sam Cole", "Joe Fenwick", "Ella Brook", "Tom Ashworth"]), onOpen: { _ in })
            TrainedWithLine(tags: tags(["Sam Cole", "Joe Fenwick", "Ella Brook", "Tom Ashworth", "Kate Simmons", "Priya Shah"]), onOpen: { _ in })
            TrainedWithLine(tags: tags(["Sam Cole", "Joe Fenwick", "Ella Brook", "Tom Ashworth", "Kate Simmons", "Priya Shah"]),
                            onOpen: { _ in }, showsEveryone: true)
        }
        .padding(Tokens.Spacing.screen)
        .frame(width: 393, alignment: .leading)
        .background(Tokens.Surface.card)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("crew-tags.png")
        try #require(image.pngData()).write(to: url)
        print("Crew tags snapshot: \(url.path)")
    }
}
