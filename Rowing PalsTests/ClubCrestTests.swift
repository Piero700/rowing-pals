//
//  ClubCrestTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// The text in onboarding's 44 pt club crest (v3 §01), and the member count it sits beside.
struct ClubCrestTests {
    private func club(_ name: String, members: Int = 48) throws -> ClubSearchViewModel.ClubResult {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"\(name)","location":"Norwich","profiles":[{"count":\(members)}]}
        """
        return try JSONDecoder().decode(ClubSearchViewModel.ClubResult.self, from: Data(json.utf8))
    }

    @Test func leadingAcronymIsTheCrest() throws {
        #expect(try club("UEA Boat Club").crest == "UEA")
    }

    @Test func otherwiseInitialsOfUpToThreeWords() throws {
        #expect(try club("Norwich Rowing Club").crest == "NRC")
        #expect(try club("Durham University Boat Club").crest == "DUB")
        #expect(try club("Tideway").crest == "T")
    }

    @Test func memberCountComesFromTheEmbeddedCount() throws {
        #expect(try club("UEA Boat Club", members: 31).memberCount == 31)
    }
}
