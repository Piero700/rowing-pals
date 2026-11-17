//
//  ScreenStackDepthTests.swift
//  Rowing PalsTests
//

import Foundation
import SwiftUI
import Testing
@testable import Rowing_Pals

/// How much stack every screen needs the first time it's built. Settings crashed the app on the
/// iPhone (15 Nov 2026) because its view type was nested so deeply that Swift's runtime ran out of
/// stack working it out; the simulator's far bigger stack hid it. Measured on 17 Nov 2026 (Debug):
/// the crashing Settings needed 829 KB, while Profile (569 KB, the deepest screen that works on the
/// phone) opens fine. A screen that grows past `limitBytes` is heading for the same crash: split its
/// sections into their own `View` structs, as `SettingsView` now does.
struct ScreenStackDepthTests {
    /// Between the deepest screen known to work on the phone and the one that crashed.
    private static let limitBytes = 700 * 1024

    @Test(arguments: Screen.allCases)
    func screenStaysWellInsideThePhonesStack(_ screen: Screen) {
        let bytes = StackProbe.peakBytes { screen.build() }
        #expect(bytes > 0 && bytes < Self.limitBytes, "\(screen.rawValue) needs \(bytes / 1024) KB of stack")
    }

    /// Prints how much stack one screen needs the first time it's built ("RP-STACK" line in the test
    /// log). Swift remembers a view type once it has worked it out, so for an exact first-open figure
    /// measure one screen per test run: pass its name in `TEST_RUNNER_RP_SCREEN` ("settings" for Settings).
    @Test func reportStackForOneScreen() {
        guard let name = ProcessInfo.processInfo.environment["RP_SCREEN"] else { return }
        let bytes: Int
        if name == "settings" {
            bytes = StackProbe.peakBytes { _ = SettingsView().body }
        } else if let screen = Screen(rawValue: name) {
            bytes = StackProbe.peakBytes { screen.build() }
        } else {
            return
        }
        print("RP-STACK \(name) \(bytes / 1024) KB")
    }

    enum Screen: String, CaseIterable, Sendable {
        case feed, rankings, rowerCalendar, profile, otherProfile, postSheet, reviewSheet, capture
        case coachRowers, coachWorkouts, coachBoats, coachCalendar
        case signIn, chooseUsername, clubSearch, clubSearchLater
        case peopleFollowers, peopleFind, followRequests, post, editProfile
        case clubHub, createClub, editClub, manageClub, coachProfile
        case coachRower, squads, squadEdit, newSquad, newWorkout, workoutResults, editWorkout, notepad, scanMonitor
        case notebook, notebookRower, pbHistory, newWorkoutOn
        case practice, newPractice, editPractice, register, attendanceTotals, availability
        case event, newEvent, editEvent, waterSession, newWaterSession, sessionBoat, savedBoat, rowerWaterSession
        case newAnnouncement, editAnnouncement, challenge, newChallenge, editChallenge
        case ergEvent, newErgEvent, editErgEvent, seasonWrapped

        @MainActor func build() {
            let id = UUID()
            let day = Date()
            switch self {
            case .feed: _ = FeedView().body
            case .rankings: _ = RankingsView().body
            case .rowerCalendar: _ = RowerCalendarView().body
            case .profile: _ = ProfileView().body
            case .otherProfile: _ = ProfileView(viewing: id).body
            case .postSheet: _ = PostSheetView().body
            case .reviewSheet:
                _ = ReviewSheetView(selfieJPEG: nil, isLiveCapture: true, initialMonitorPhoto: nil, onPosted: {}).body
            case .capture: _ = CaptureView(onPosted: {}, onClose: {}).body
            case .coachRowers: _ = CoachRowersView().body
            case .coachWorkouts: _ = CoachWorkoutsView().body
            case .coachBoats: _ = CoachBoatsView().body
            case .coachCalendar: _ = CoachCalendarView().body
            case .signIn: _ = SignInView().body
            case .chooseUsername: _ = ChooseUsernameView(name: "Test", onDone: {}).body
            case .clubSearch: _ = ClubSearchView().body
            case .clubSearchLater: _ = ClubSearchView(mode: .joinLater).body
            case .peopleFollowers: _ = PeopleListView(kind: .followers(id)).body
            case .peopleFind: _ = PeopleListView(kind: .find).body
            case .followRequests: _ = FollowRequestsView().body
            case .post: _ = PostDetailView(sessionId: id).body
            case .editProfile: _ = EditProfileView(viewModel: SettingsViewModel()).body
            case .clubHub: _ = ClubHubView().body
            case .createClub: _ = ClubFormView(mode: .create).body
            case .editClub: _ = ClubFormView(mode: .edit).body
            case .manageClub: _ = ManageClubView().body
            case .coachProfile: _ = CoachProfileView().body
            case .coachRower: _ = CoachRowerView(userId: id).body
            case .squads: _ = SquadsView().body
            case .squadEdit: _ = SquadEditView(squadId: id).body
            case .newSquad: _ = SquadEditView(squadId: nil).body
            case .newWorkout: _ = NewWorkoutView().body
            case .workoutResults: _ = WorkoutResultsView(workoutId: id).body
            case .editWorkout: _ = NewWorkoutView(editing: id).body
            case .notepad: _ = NotepadView(workoutId: id).body
            case .scanMonitor: _ = ScanMonitorView(workoutId: id, rowerId: id).body
            case .notebook: _ = NotebookView().body
            case .notebookRower: _ = NotebookRowerView(rowerId: id).body
            case .pbHistory:
                if let test = StandardTest.all.first { _ = PBHistoryView(test: test, userId: id).body }
            case .newWorkoutOn: _ = NewWorkoutView(date: day).body
            case .practice: _ = RowerPracticeView(practiceId: id).body
            case .newPractice: _ = PracticeEditorView(practiceId: nil, day: day).body
            case .editPractice: _ = PracticeEditorView(practiceId: id, day: nil).body
            case .register: _ = RegisterView(practiceId: id).body
            case .attendanceTotals: _ = AttendanceTotalsView().body
            case .availability: _ = AvailabilityView().body
            case .event: _ = EventView(eventId: id).body
            case .newEvent: _ = EventEditorView(eventId: nil, kind: .race, day: day).body
            case .editEvent: _ = EventEditorView(eventId: id).body
            case .waterSession: _ = WaterSessionView(sessionId: id).body
            case .newWaterSession: _ = WaterSessionView(sessionId: nil, seed: WaterSessionSeed(day: day)).body
            case .sessionBoat: _ = CrewBoatView(mode: .session(id, boat: nil)).body
            case .savedBoat: _ = CrewBoatView(mode: .saved(id)).body
            case .rowerWaterSession: _ = RowerWaterSessionView(sessionId: id).body
            case .newAnnouncement: _ = AnnouncementEditorView(announcementId: nil).body
            case .editAnnouncement: _ = AnnouncementEditorView(announcementId: id).body
            case .challenge: _ = ChallengeDetailView(challengeId: id).body
            case .newChallenge: _ = ChallengeEditorView(challengeId: nil).body
            case .editChallenge: _ = ChallengeEditorView(challengeId: id).body
            case .ergEvent: _ = ErgEventDetailView(eventId: id).body
            case .newErgEvent: _ = ErgEventEditorView(eventId: nil).body
            case .editErgEvent: _ = ErgEventEditorView(eventId: id).body
            case .seasonWrapped: _ = WrappedView(termId: nil).body
            }
        }
    }
}
