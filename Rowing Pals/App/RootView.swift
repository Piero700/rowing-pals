//
//  RootView.swift
//  Rowing Pals
//

import SwiftUI

/// The app shell. Redesigned 2026-09-17 (phase A) to match
/// docs/design/rowing-pals-redesign-handoff-v2.md §4: the bottom nav is
/// two separate floating glass shapes, not one bar — a
/// Feed/Rankings/Profile pill plus a standalone circular Log button — so
/// this hand-builds tab switching instead of a native `TabView` (which can
/// only float one unified bar). See `FloatingTabBar` and
/// `FloatingBarVisibility` for the bar itself and the scroll-linked
/// behaviour that replaces `.tabBarMinimizeBehavior`.
///
/// Real-device feedback (2026-09-17) fixed two structural issues here,
/// not just tuning:
///
/// 1. All three tabs are instantiated once, up front, and shown/hidden
///    with opacity + `allowsHitTesting` — **not** a `switch` that creates
///    a fresh view every time you change tabs. A `switch`-built view loses
///    identity on every switch: a brand-new `FeedViewModel` means a reset
///    scroll position and a full reload each time you come back to a tab,
///    which is exactly what read as "can't smoothly move between tabs" —
///    native `TabView` keeps every tab alive for this reason, and losing
///    that was a real regression, not a preference.
/// 2. `FloatingTabBar` sits in `content`'s own `.overlay(alignment: .bottom)`
///    rather than a sibling in a bespoke `ZStack` inside a `GeometryReader`
///    — `.overlay` is the pattern already proven elsewhere in this codebase
///    for floating UI on top of a `ScrollView` (e.g. `MetresLeaderboardView`'s
///    pinned row) and composes hit-testing predictably; taps meant for the
///    bar were occasionally reaching a feed card underneath instead with
///    the old structure. No extra minimum bottom padding either — SwiftUI
///    already keeps an `.overlay` clear of the safe area on its own, which
///    also happens to sit the bar closer to the true bottom edge, matching
///    the Instagram-style closeness asked for.
struct RootView: View {
    private enum RootTab: Hashable {
        case feed, rankings, profile
    }

    @State private var selection: RootTab = .feed
    @State private var isShowingPostSheet = false
    @State private var barVisibility = FloatingBarVisibility()
    /// Redesign phase E: a rower's profile (and the people lists reached from
    /// it) opens over the tabs. Features raise an `AppRoute` through the
    /// `navigate` environment action; this is the one place that turns it
    /// into a screen.
    @State private var presentedRoute: AppRoute?
    /// A tapped push alert's post arrives here (docs/design/v2-decisions.md #19).
    @State private var push = PushNotificationService.shared
    @State private var membershipMonitor = MembershipMonitor()
    /// Counts taps on a tab while it's already showing; that tab scrolls to the top and
    /// refreshes (decision 27).
    @State private var reselects: [RootTab: Int] = [:]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark

    /// House/bar-chart/person — matches the prototype's actual inline SVG
    /// icon defs (`#home`/`#rank`/`#user`), not a guess at "something
    /// feed-like" — confirmed against the prototype file directly, not
    /// just the earlier design summary.
    private static let items: [FloatingTabBar<RootTab>.Item] = [
        .init(tab: .feed, label: "Feed", systemImage: "house"),
        .init(tab: .rankings, label: "Rankings", systemImage: "chart.bar"),
        .init(tab: .profile, label: "Profile", systemImage: "person")
    ]

    var body: some View {
        content
            .overlay {
                // A full-height stack that runs under the bottom safe area, so the bar's own
                // 6 pt bottom inset is measured from the screen edge, as in v3. Only the bar
                // itself takes touches; the Spacer passes them through.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                    FloatingTabBar(
                        items: Self.items,
                        selection: $selection,
                        onReselect: { tab in reselects[tab, default: 0] += 1 },
                        onTapLog: { isShowingPostSheet = true }
                    )
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .environment(barVisibility)
            .environment(\.navigate, NavigateAction { route in
                if route == .log {
                    isShowingPostSheet = true
                } else {
                    presentedRoute = route
                }
            })
            // v3: Log opens capture as a full-screen modal, no tab bar.
            .fullScreenCover(isPresented: $isShowingPostSheet) {
                PostSheetView()
            }
            .fullScreenCover(item: $presentedRoute) { route in
                RouteHost(root: route)
            }
            .task { await push.start() }
            // An admin elsewhere can accept, remove or promote this rower; reload when they do.
            .task { await membershipMonitor.run() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await membershipMonitor.check() } }
            }
            .onChange(of: push.pendingRoute, initial: true) {
                // Next run loop: on a launch from an alert, the window is still being set up.
                Task { openPendingRoute() }
            }
    }

    /// Opens a tapped alert's post over whatever is showing (see `AlertRoutePresenter`).
    private func openPendingRoute() {
        guard let route = push.pendingRoute,
              AlertRoutePresenter.present(route, colorScheme: appearance.colorScheme) else { return }
        push.pendingRoute = nil
    }

    /// All three live simultaneously — see the doc comment above for why.
    private var content: some View {
        ZStack {
            tab(.feed) { FeedView(reselects: reselects[.feed, default: 0]) }
            tab(.rankings) { RankingsView(reselects: reselects[.rankings, default: 0]) }
            tab(.profile) { ProfileView(reselects: reselects[.profile, default: 0]) }
        }
        // Reaches the physical bottom edge so the nav can sit 6 pt above it, as in v3; each
        // tab's scroll view already runs under the bottom safe area.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func tab(_ tab: RootTab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(selection == tab ? 1 : 0)
            // Screens swap at once, like a standard iOS tab bar; only the bar's thumb slides.
            // (The thumb's spring used to cross-fade all three screens, glass and all, for about
            // half a second on every tab tap.)
            .animation(nil, value: selection)
            .allowsHitTesting(selection == tab)
    }
}

#Preview {
    RootView()
}
