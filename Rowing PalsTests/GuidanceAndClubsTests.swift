//
//  GuidanceAndClubsTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Decision 98: helper text hides after 7 separate local days of use unless the person chooses;
/// club names are unique ignoring capitals and spaces; the verified flag reads before its
/// migration; and a live monitor photo without a selfie still counts like a photographed session.
@MainActor
struct GuidanceAndClubsTests {
    // MARK: - The 7-day rule

    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        return calendar
    }()

    private static func date(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: text) ?? .distantPast
    }

    @Test func helperTextShowsUntilTheSeventhDay() {
        var stored = ""
        for day in 1...6 {
            stored = GuidanceRules.recording(String(format: "2026-11-%02d", day), in: stored)
            #expect(GuidanceRules.showsGuidance(storedDays: stored, choice: .automatic))
        }
        stored = GuidanceRules.recording("2026-11-07", in: stored)
        #expect(!GuidanceRules.showsGuidance(storedDays: stored, choice: .automatic))
    }

    @Test func openingTheAppTwiceOnOneDayCountsOnce() {
        var stored = ""
        for _ in 1...10 { stored = GuidanceRules.recording("2026-11-05", in: stored) }
        #expect(GuidanceRules.days(from: stored) == ["2026-11-05"])
        #expect(GuidanceRules.showsGuidance(storedDays: stored, choice: .automatic))
    }

    @Test func daysDontHaveToBeInARow() {
        let days = ["2026-11-01", "2026-11-03", "2026-11-10", "2026-12-01", "2027-01-15", "2027-02-02"]
        let stored = days.reduce("") { GuidanceRules.recording($1, in: $0) }
        #expect(GuidanceRules.showsGuidance(storedDays: stored, choice: .automatic))
        #expect(!GuidanceRules.showsGuidance(storedDays: GuidanceRules.recording("2027-03-01", in: stored), choice: .automatic))
    }

    @Test func theListStopsGrowingAtSeven() {
        let stored = (1...20).reduce("") { GuidanceRules.recording(String(format: "2026-11-%02d", $1), in: $0) }
        #expect(GuidanceRules.days(from: stored).count == GuidanceRules.daysUntilHidden)
    }

    @Test func theDayIsTheLocalCalendarDayNotUTC() {
        // 23:30 in London on 31 March (BST, UTC+1) is 22:30 UTC — still the 31st either way; and
        // 00:30 BST on 1 April is 23:30 UTC on the 31st, but the person's day is the 1st.
        let lateEvening = Self.date("2026-03-31T22:30:00Z")
        let justAfterMidnight = Self.date("2026-03-31T23:30:00Z")
        #expect(GuidanceRules.dayKey(for: lateEvening, calendar: Self.london) == "2026-03-31")
        #expect(GuidanceRules.dayKey(for: justAfterMidnight, calendar: Self.london) == "2026-04-01")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        #expect(GuidanceRules.dayKey(for: justAfterMidnight, calendar: utc) == "2026-03-31")
    }

    @Test func theirOwnChoiceWinsOverTheCount() {
        let sevenDays = (1...7).reduce("") { GuidanceRules.recording(String(format: "2026-11-%02d", $1), in: $0) }
        #expect(GuidanceRules.showsGuidance(storedDays: sevenDays, choice: .on))
        #expect(!GuidanceRules.showsGuidance(storedDays: "", choice: .off))
        #expect(!GuidanceRules.showsGuidance(storedDays: "2026-11-01", choice: .off))
        #expect(GuidanceRules.Choice(rawValue: "") == .automatic)
        #expect(GuidanceRules.Choice(rawValue: "on") == .on)
    }

    // MARK: - Club names

    @Test func namesAreTidiedAsTheDatabaseStoresThem() {
        #expect(ClubNameRules.tidied("  Tyne   Rowing  Club ") == "Tyne Rowing Club")
        #expect(ClubNameRules.tidied("UEA\tBoat\nClub") == "UEA Boat Club")
    }

    @Test func capitalsAndSpacesDontMakeANewName() {
        #expect(ClubNameRules.isSameName("Tyne RC", "tyne rc"))
        #expect(ClubNameRules.isSameName("Tyne RC", "  TYNE   RC "))
        #expect(ClubNameRules.key("Tyne  RC") == "tyne rc")
        #expect(!ClubNameRules.isSameName("Tyne RC", "Tyne ARC"))
        #expect(!ClubNameRules.isSameName("Tyne RC", "TyneRC"))
    }

    @Test func aNameNeedsSomethingAndFitsSixtyCharacters() {
        #expect(ClubNameRules.problem(with: "") == "Give your club a name.")
        #expect(ClubNameRules.problem(with: "    ") == "Give your club a name.")
        #expect(ClubNameRules.problem(with: "Tyne RC") == nil)
        #expect(ClubNameRules.problem(with: String(repeating: "a", count: 60)) == nil)
        #expect(ClubNameRules.problem(with: String(repeating: "a", count: 61)) == "Club names can be up to 60 characters.")
        // Extra spaces don't count towards the limit: they're taken out before saving.
        #expect(ClubNameRules.problem(with: "  " + String(repeating: "a", count: 60) + "  ") == nil)
    }

    @Test func theTakenMessageNamesTheClub() {
        #expect(ClubNameRules.takenMessage(for: " tyne  rc ").hasPrefix("There’s already a club called tyne rc."))
    }

    // MARK: - The verified flag

    @Test func theVerifiedFlagReadsBeforeAndAfterTheMigration() throws {
        let before = try JSONDecoder().decode(ClubNameRef.self, from: Data(#"{"name":"Tyne RC"}"#.utf8))
        #expect(before == ClubNameRef(name: "Tyne RC", isVerified: false))
        let after = try JSONDecoder().decode(ClubNameRef.self, from: Data(#"{"name":"Tyne RC","is_verified":true}"#.utf8))
        #expect(after.isVerified)
    }

    // MARK: - No selfie

    @Test func aLiveMonitorPhotoWithoutASelfieIsNotManual() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil, isLiveCapture: true, startsBlank: false)
        #expect(!vm.isManual)
        #expect(vm.segments.isEmpty)
        // It can be a test, as a photographed session can.
        #expect(vm.availableKinds.count > 1)
    }

    @Test func aLibraryPhotoStaysManual() {
        let vm = ReviewSheetViewModel(selfieJPEG: nil, isLiveCapture: false, startsBlank: false)
        #expect(vm.isManual)
        #expect(vm.availableKinds == [.training])
    }
}
