//
//  CoachRootView.swift
//  Rowing Pals
//

import SwiftUI

/// The coach version's shell (decision 67): its own floating bar — Rowers, Workouts, Boats and
/// Calendar in the glass pill, the solid + beside it, which asks Land session, Water session or
/// Announcement —
/// built like the rower's `RootView`.
///
/// Every tab lives at once and is shown or hidden, so each keeps its scroll position. Anything a
/// tab opens appears full screen over the bar through `RouteHost`, as in the rower version; when it
/// closes, the tabs reload, so a new workout or a changed squad shows straight away.
struct CoachRootView: View {
    private enum CoachTab: Hashable {
        case rowers, workouts, boats, calendar
    }

    @State private var selection: CoachTab = .rowers
    @State private var barVisibility = FloatingBarVisibility()
    @State private var presentedRoute: AppRoute?
    /// + asks Land session or Water session; the choice opens once the sheet has gone.
    @State private var isChoosingNew = false
    @State private var chosenRoute: AppRoute?
    @State private var reselects: [CoachTab: Int] = [:]
    /// Counts screens closed over the tabs; each tab reloads when it changes.
    @State private var refreshes = 0
    @State private var push = PushNotificationService.shared
    @State private var membershipMonitor = MembershipMonitor()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark

    private static let items: [FloatingTabBar<CoachTab>.Item] = [
        .init(tab: .rowers, label: "Rowers", systemImage: "person.2"),
        .init(tab: .workouts, label: "Workouts", systemImage: "stopwatch"),
        .init(tab: .boats, label: "Boats", systemImage: "water.waves"),
        .init(tab: .calendar, label: "Calendar", systemImage: "calendar")
    ]

    var body: some View {
        content
            .overlay {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                    FloatingTabBar(
                        items: Self.items,
                        selection: $selection,
                        onReselect: { tab in reselects[tab, default: 0] += 1 },
                        logLabel: "New: session or announcement",
                        onTapLog: { isChoosingNew = true }
                    )
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .environment(barVisibility)
            .environment(\.navigate, NavigateAction { route in
                // A coach logs nothing here: Log belongs to the rower version.
                if route == .log { return }
                if case .logWorkout = route { return }
                presentedRoute = route
            })
            .sheet(isPresented: $isChoosingNew, onDismiss: {
                if let route = chosenRoute {
                    chosenRoute = nil
                    presentedRoute = route
                }
            }) {
                NewSessionSheet { route in
                    chosenRoute = route
                    isChoosingNew = false
                }
            }
            .fullScreenCover(item: $presentedRoute, onDismiss: { refreshes += 1 }) { route in
                RouteHost(root: route)
            }
            .task { await push.start() }
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

    private var content: some View {
        ZStack {
            tab(.rowers) { CoachRowersView(reselects: reselects[.rowers, default: 0], refreshes: refreshes) }
            tab(.workouts) { CoachWorkoutsView(reselects: reselects[.workouts, default: 0], refreshes: refreshes) }
            tab(.boats) { CoachBoatsView(reselects: reselects[.boats, default: 0], refreshes: refreshes) }
            tab(.calendar) { CoachCalendarView(reselects: reselects[.calendar, default: 0], refreshes: refreshes) }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func tab(_ tab: CoachTab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(selection == tab ? 1 : 0)
            .animation(nil, value: selection)
            .allowsHitTesting(selection == tab)
    }
}
