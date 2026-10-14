//
//  DurationEntryTests.swift
//  Rowing PalsTests
//

import Testing
@testable import Rowing_Pals

/// Typing times: the colon is put in for you, and a half-typed time never crashes the parser
/// (user, 2026-10-12: typing "5:" in a workout's rest crashed the app).
struct DurationEntryTests {
    @Test func aTrailingColonIsNotATimeAndDoesNotCrash() {
        #expect(DurationParsing.parseMs("5:") == nil)
        #expect(DurationParsing.parseMs(":") == nil)
        #expect(DurationParsing.parseMs("1:05:") == nil)
        #expect(DurationParsing.parseMs("5:00") == 300_000)
    }

    @Test func digitsFillFromTheRightWithTheColonInPlace() {
        #expect(DurationEntry.text(digits: "") == "")
        #expect(DurationEntry.text(digits: "5") == "0:05")
        #expect(DurationEntry.text(digits: "50") == "0:50")
        #expect(DurationEntry.text(digits: "500") == "5:00")
        #expect(DurationEntry.text(digits: "2000") == "20:00")
        #expect(DurationEntry.text(digits: "6000") == "60:00")
        #expect(DurationEntry.text(digits: "13000") == "1:30:00")
    }

    @Test func typingIntoTheShownTextKeepsJustTheDigits() {
        // "5:00" with another 0 typed after it.
        #expect(DurationEntry.digits(from: "5:000") == "5000")
        // Deleting the last character of "5:00".
        #expect(DurationEntry.digits(from: "5:0") == "50")
        // A pasted colon or letters are ignored, never a crash.
        #expect(DurationEntry.digits(from: "1:42abc") == "142")
        #expect(DurationEntry.digits(from: "1234567") == "123456")
    }

    @Test func digitsBecomeMilliseconds() {
        #expect(DurationEntry.milliseconds(digits: "500") == 300_000)
        #expect(DurationEntry.milliseconds(digits: "6000") == 3_600_000)
        #expect(DurationEntry.milliseconds(digits: "13000") == 5_400_000)
        #expect(DurationEntry.milliseconds(digits: "175") == nil)    // 1:75
        #expect(DurationEntry.milliseconds(digits: "") == nil)
        #expect(DurationEntry.digits(milliseconds: 300_000) == "500")
        #expect(DurationEntry.digits(milliseconds: 5_400_000) == "13000")
    }

    // MARK: - The session time, with the monitor's tenth (2026-10-14)

    @Test func theDecimalKeyAddsATenth() {
        #expect(DurationEntry.entry(from: "702.4", allowsTenths: true) == "702.4")
        #expect(DurationEntry.text(entry: "702.4") == "7:02.4")
        // While the tenth is still to come.
        #expect(DurationEntry.text(entry: "702.") == "7:02.")
        // Without a tenth it's an ordinary time.
        #expect(DurationEntry.text(entry: "702") == "7:02")
        // A comma key works the same; a second mark and a second tenth digit are ignored.
        #expect(DurationEntry.entry(from: "702,4", allowsTenths: true) == "702.4")
        #expect(DurationEntry.entry(from: "702.45", allowsTenths: true) == "702.4")
        #expect(DurationEntry.entry(from: "70.2.4", allowsTenths: true) == "70.2")
        // Where tenths aren't taken, everything from the mark is dropped.
        #expect(DurationEntry.entry(from: "702.4", allowsTenths: false) == "702")
    }

    @Test func theShownTimeReadsBackAsItsEntry() {
        // The field is seeded from what it shows, including a time read off the monitor.
        #expect(DurationEntry.entry(from: "7:02.4", allowsTenths: true) == "702.4")
        #expect(DurationEntry.entry(from: "1:05:00", allowsTenths: true) == "10500")
    }

    @Test func entriesBecomeMilliseconds() {
        #expect(DurationEntry.milliseconds(entry: "702.4") == 422_400)
        #expect(DurationEntry.milliseconds(entry: "702.") == 422_000)
        #expect(DurationEntry.milliseconds(entry: "702") == 422_000)
        #expect(DurationEntry.milliseconds(entry: "10500.3") == 3_900_300)
        #expect(DurationEntry.milliseconds(entry: "75.2") == nil)     // 0:75.2
        #expect(DurationEntry.milliseconds(entry: ".4") == nil)
        #expect(DurationEntry.milliseconds(entry: "") == nil)
        #expect(DurationEntry.entry(milliseconds: 422_400) == "702.4")
        #expect(DurationEntry.entry(milliseconds: 422_000) == "702")
        #expect(DurationEntry.entry(milliseconds: 422_450) == "702.4")
    }
}
