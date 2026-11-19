//
//  TourSnapshotTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// The first-run tour (decision 109) over the real tab bar, at iPhone 17 Pro size. Writes
/// $TMPDIR/tour-*.png.
@MainActor
struct TourSnapshotTests {
    private static let rowerItems: [FloatingTabBar<String>.Item] = [
        .init(tab: "Feed", label: "Feed", icon: .home),
        .init(tab: "Rankings", label: "Rankings", icon: .rankings),
        .init(tab: "Calendar", label: "Calendar", icon: .calendar),
        .init(tab: "Profile", label: "Profile", icon: .profile)
    ]
    private static let coachItems: [FloatingTabBar<String>.Item] = [
        .init(tab: "Rowers", label: "Rowers", icon: .people),
        .init(tab: "Workouts", label: "Workouts", icon: .stopwatch),
        .init(tab: "Boats", label: "Boats", icon: .boat),
        .init(tab: "Calendar", label: "Calendar", icon: .calendar)
    ]

    @Test(arguments: [
        ("rower-1-dark", AppMode.rowing, 0, ColorScheme.dark),
        ("rower-2-dark", .rowing, 1, .dark),
        ("rower-5-light", .rowing, 4, .light),
        ("coach-5-dark", .coaching, 4, .dark)
    ])
    func tourCard(name: String, mode: AppMode, index: Int, scheme: ColorScheme) throws {
        let steps = TourRules.steps(for: mode)
        let items = mode == .rowing ? Self.rowerItems : Self.coachItems
        let selected: String = if case .tab(let label) = steps[index].target { label } else { items[0].tab }
        let view = ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                Text(selected).textStyle(Typography.largeTitle).foregroundStyle(Tokens.Ink.primary)
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Tokens.Radius.card).fill(Tokens.Surface.card).frame(height: 150)
                }
                Spacer()
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 70)
            FloatingTabBar(items: items, selection: .constant(selected), onTapLog: {})
                .padding(.bottom, 28)
        }
        .frame(width: 402, height: 874)
        .background(Tokens.Base.ground)
        .overlayPreferenceValue(TourTargetKey.self) { targets in
            TourOverlay(steps: steps, index: .constant(index), targets: targets, onFinish: {})
        }
        .environment(FloatingBarVisibility())
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tour-\(name).png")
        try #require(image.pngData()).write(to: url)
        print("TOUR-SNAPSHOT \(url.path)")
    }
}
