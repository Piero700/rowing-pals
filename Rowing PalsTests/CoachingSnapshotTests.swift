//
//  CoachingSnapshotTests.swift
//  Rowing PalsTests
//

import PaceEngine
import SwiftUI
import Testing
@testable import Rowing_Pals

/// Renders Coaching's pieces with sample rowers to PNGs, to compare with the canvas
/// (docs/design/v4/Coach*.dc.html) without a club full of coaches and data. Writes to
/// $TMPDIR/coaching-*.png and checks each render produced an image. (Sheets that scroll, like the
/// join notice, don't draw in `ImageRenderer`; they're checked on the simulator.)
@MainActor
struct CoachingSnapshotTests {
    private static let width: CGFloat = 393

    @Test func rowerCardsRender() throws {
        let rowers = [
            Self.rower("Marcus Reilly", squads: ["Novices"], metres: 0, target: 40_000, sessions: 0, shortfall: 22_000,
                       twoK: 442_000, flags: [.noRecentSession(days: 12)]),
            Self.rower("Joe Fenwick", squads: ["Novices"], isCoach: true, metres: 22_000, target: 45_000, sessions: 2,
                       shortfall: 3_700, twoK: 425_200, flags: [.likelyMistagged(logged: .ut2, likely: .ut1, spreadSeconds: 5.2)]),
            Self.rower("Nina Bergström", squads: ["Novices"], metres: 26_000, target: 40_000, sessions: 3, shortfall: 0,
                       twoK: 461_300, flags: [])
        ]
        let view = VStack(spacing: Tokens.Spacing.tight) {
            ForEach(rowers) { RowerCard(rower: $0) }
        }
        .padding(Tokens.Spacing.screen)
        try Self.render(view, name: "rower-cards")
    }

    @Test func rowerChartsRender() throws {
        let calendar = Calendar.current
        let starts = CoachingRules.weekStarts(weeks: 8, asOf: Date(), calendar: calendar)
        let view = VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack(spacing: 6) {
                FlagChip(text: "Age 22")
                FlagChip(text: "74.0 kg")
                FlagChip(text: "Private account")
                FlagChip(text: "No session in 12 days", isWarning: true)
            }
            VolumeBars(weeks: [52_000, 61_000, 48_000, 66_000, 70_000, 58_000, 74_000, 71_400], weekStarts: starts)
                .padding(Tokens.Spacing.card)
                .background(Tokens.Surface.card)
            ZoneMixBar(shares: [
                .init(zone: .ut2, share: 0.62), .init(zone: .ut1, share: 0.21), .init(zone: .at, share: 0.09),
                .init(zone: .tr, share: 0.05), .init(zone: .an, share: 0.03)
            ])
            .padding(Tokens.Spacing.card)
            .background(Tokens.Surface.card)
            EffortTrendChart(weeks: [5.5, 5.8, 6.0, 5.6, 6.4, 7.0, 7.4, 7.9], average: 6.2, isElevated: true)
                .padding(Tokens.Spacing.card)
                .background(Tokens.Surface.card)
        }
        .padding(Tokens.Spacing.screen)
        try Self.render(view, name: "rower-charts")
    }

    // MARK: - Helpers

    private static func render(_ content: some View, name: String) throws {
        for scheme in [ColorScheme.dark, .light] {
            let view = content
                .frame(width: width)
                .background(Tokens.Base.ground)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            let data = try #require(image.pngData())
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("coaching-\(name)-\(scheme == .dark ? "dark" : "light").png")
            try data.write(to: url)
            print("Coaching snapshot: \(url.path)")
            #expect(image.size.width > 0)
        }
    }

    private static func rower(
        _ name: String, squads: [String], isCoach: Bool = false, metres: Int, target: Int, sessions: Int,
        shortfall: Int, twoK: Int?, flags: [CoachFlag]
    ) -> CoachRower {
        CoachRower(
            id: UUID(), displayName: name, avatarPath: nil, category: .novice, gender: .male, isPrivate: false,
            isCoach: isCoach, squadNames: squads, squadIds: [], weekMetres: metres, weekSessions: sessions,
            weeklyTargetM: target, daysSinceSession: 2, twoKBestMs: twoK, prediction: nil, flags: flags,
            shortfallM: shortfall
        )
    }
}
