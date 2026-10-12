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
}
