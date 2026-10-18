//
//  RouteHost.swift
//  Rowing Pals
//

import SwiftUI

/// Presents an `AppRoute` over the tabs and keeps a navigation stack for
/// everything reachable from it: profile → followers → another profile →
/// and so on. `App/` is the one layer allowed to know every feature, so this
/// is where routes become screens — features themselves only raise routes
/// (CLAUDE.md: no feature imports another feature).
struct RouteHost: View {
    let root: AppRoute

    @State private var path: [AppRoute] = []
    @Environment(\.dismiss) private var dismiss
    /// The tab bar's scroll-tracking state belongs to the tabs; a profile in
    /// here gets its own so scrolling it doesn't move a bar that isn't
    /// on screen.
    @State private var barVisibility = FloatingBarVisibility()
    /// Settings opens as a sheet, as from the rower's Profile (it has its own navigation stack).
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            destination(root)
                // Swipe from the left edge to close this area, like going back (decision 61).
                .edgeSwipeToDismiss()
                // The workout screen draws its own back button over its photo.
                .toolbar(Self.drawsOwnChrome(root) ? .hidden : .visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            RPIconView(icon: .close)
                                .textStyle(Typography.rowTitle)
                        }
                        .accessibilityLabel("Close")
                    }
                }
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                        // The stack's own swipe takes a pushed screen back (decision 61).
                        .swipeBackHandledByStack()
                }
        }
        .tint(Tokens.Accent.brand)
        .environment(barVisibility)
        .environment(\.closeRoute, CloseRouteAction { dismiss() })
        .environment(\.navigate, NavigateAction { route in
            // Log belongs to the tab screens; it can't be pushed here.
            if route == .log { return }
            if case .logWorkout = route { return }
            if route == .settings {
                isShowingSettings = true
            } else {
                path.append(route)
            }
        })
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }

    /// The workout, rower profile and people screens draw their own v3 back button and title.
    private static func drawsOwnChrome(_ route: AppRoute) -> Bool {
        switch route {
        case .post, .profile, .people, .findClub, .clubHub, .createClub, .editClub, .manageClub,
             .coachProfile, .editProfile, .coachRower, .squads, .squadEdit, .pbHistory, .newWorkout, .workoutResults,
             .newWorkoutOn, .practice, .newPractice, .editPractice, .register, .attendanceTotals, .availability,
             .event, .newEvent, .editEvent, .waterSession, .newWaterSession, .sessionBoat, .savedBoat, .newAnnouncement, .editAnnouncement,
             .challenge, .newChallenge, .editChallenge, .ergEvent, .newErgEvent, .editErgEvent, .seasonWrapped: true
        default: false
        }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .profile(let userId):
            ProfileView(viewing: userId)
        case .people(let kind):
            PeopleListView(kind: kind)
        case .followRequests:
            FollowRequestsView()
        case .log, .logWorkout:
            EmptyView()
        case .findClub:
            ClubSearchView(mode: .joinLater)
        case .clubHub:
            ClubHubView()
        case .createClub:
            ClubFormView(mode: .create)
        case .editClub:
            ClubFormView(mode: .edit)
        case .manageClub:
            ManageClubView()
        case .coachProfile:
            CoachProfileView()
        case .settings:
            // Shown as a sheet by `navigate`; never pushed.
            EmptyView()
        case .editProfile:
            EditProfileHost()
        case .coachRower(let userId):
            CoachRowerView(userId: userId)
        case .squads:
            SquadsView()
        case .squadEdit(let squadId):
            SquadEditView(squadId: squadId)
        case .newWorkout:
            NewWorkoutView()
        case .workoutResults(let workoutId):
            WorkoutResultsView(workoutId: workoutId)
        case .newWorkoutOn(let day):
            NewWorkoutView(date: day)
        case .practice(let practiceId):
            RowerPracticeView(practiceId: practiceId)
        case .newPractice(let day):
            PracticeEditorView(practiceId: nil, day: day)
        case .editPractice(let practiceId):
            PracticeEditorView(practiceId: practiceId, day: nil)
        case .register(let practiceId):
            RegisterView(practiceId: practiceId)
        case .attendanceTotals:
            AttendanceTotalsView()
        case .availability:
            AvailabilityView()
        case .event(let eventId):
            EventView(eventId: eventId)
        case .newEvent(let kind, let day):
            EventEditorView(eventId: nil, kind: kind, day: day)
        case .editEvent(let eventId):
            EventEditorView(eventId: eventId)
        case .waterSession(let sessionId):
            WaterSessionView(sessionId: sessionId)
        case .newWaterSession(let seed):
            WaterSessionView(sessionId: nil, seed: seed)
        case .sessionBoat(let sessionId, let boatId):
            CrewBoatView(mode: .session(sessionId, boat: boatId))
        case .savedBoat(let id):
            CrewBoatView(mode: .saved(id))
        case .rowerWaterSession(let sessionId):
            RowerWaterSessionView(sessionId: sessionId)
        case .newAnnouncement:
            AnnouncementEditorView(announcementId: nil)
        case .editAnnouncement(let id):
            AnnouncementEditorView(announcementId: id)
        case .challenge(let id):
            ChallengeDetailView(challengeId: id)
        case .newChallenge:
            ChallengeEditorView(challengeId: nil)
        case .editChallenge(let id):
            ChallengeEditorView(challengeId: id)
        case .ergEvent(let id):
            ErgEventDetailView(eventId: id)
        case .newErgEvent:
            ErgEventEditorView(eventId: nil)
        case .editErgEvent(let id):
            ErgEventEditorView(eventId: id)
        case .seasonWrapped(let termId):
            WrappedView(termId: termId)
        case .pbHistory(let test, let userId):
            PBHistoryView(test: test, userId: userId)
                .toolbar(.hidden, for: .navigationBar)
        case .post(let sessionId):
            PostDetailView(sessionId: sessionId)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
