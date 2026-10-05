//
//  RankingsView.swift
//  Rowing Pals
//

import SwiftUI

/// Redesign phase A: merges the old Metres and Tests tabs into one Rankings
/// tab with an internal Volume / Test results toggle — see
/// docs/design/rowing-pals-redesign-handoff-v2.md §2 (Screen 03) and §4.
///
/// `body` is a bare `switch`, not wrapped in any container of its own —
/// `MetresLeaderboardView`/`TestsView` each stay a `ScrollView` at their
/// own root (the same constraint `FeedView` documents: a tab's root
/// `ScrollView` must be the *direct* child of the tab's content view for
/// `.tabBarMinimizeBehavior(.onScrollDown)` to track it). Wrapping this
/// switch in a shared header+VStack would nest that ScrollView one level
/// too deep and break the minimize behaviour — so instead, each branch
/// renders the shared "Rankings" title and mode toggle as its own first
/// scroll-content row, via `mode`.
///
/// Previously two separate features (Leaderboards, Tests) — folded into
/// one `Rankings` feature folder now that they're one screen, so this
/// isn't "one feature importing another" (CLAUDE.md's architecture rule).
/// Screen 03 — Rankings (docs/design/rowing-pals-v3-spec.md; `RP Screen.dc.html` §03): a pinned
/// large-title header, then Volume or Test results.
struct RankingsView: View {
    /// Goes up by one each time Rankings is tapped while already selected (decision 27).
    var reselects = 0

    @State private var mode: RankingsMode = .volume

    var body: some View {
        Group {
            switch mode {
            case .volume:
                MetresLeaderboardView(mode: $mode, reselects: reselects)
            case .tests:
                TestsView(showsOwnTitle: false, mode: $mode, reselects: reselects)
            }
        }
        // The two boards swap at once rather than cross-fading under the control's spring.
        .animation(nil, value: mode)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("Rankings")
                    .textStyle(Typography.largeTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.horizontal, Tokens.Spacing.headerHorizontal)
            .padding(.bottom, 14)
            .frame(minHeight: Tokens.Size.headerMinHeight)
            .background(Tokens.Base.ground)
        }
    }
}

enum RankingsMode: Int, CaseIterable {
    case volume, tests

    var label: String {
        switch self {
        case .volume: "Volume"
        case .tests: "Test results"
        }
    }
}

/// The shared "Rankings" title + Volume/Test results toggle, rendered as
/// the first row inside whichever mode's own `ScrollView` is active.
/// The Volume / Test results control at the top of each Rankings mode. (The "Rankings" title
/// is pinned above by `RankingsView`.)
struct RankingsHeader: View {
    @Binding var mode: RankingsMode

    var body: some View {
        PillSegmentedControl(
            options: RankingsMode.allCases.map(\.label),
            selection: Binding(
                get: { mode.rawValue },
                set: { mode = RankingsMode(rawValue: $0) ?? .volume }
            )
        )
    }
}

#Preview {
    RankingsView()
}
