//
//  UsernameTests.swift
//  Rowing PalsTests
//

import SwiftUI
import Testing
@testable import Rowing_Pals

/// Decision 85: usernames — the rules (as the database's), suggestions from a name, and telling an
/// email from a username in the one sign-in box; plus renders of the screens that use them.
@MainActor
struct UsernameTests {
    @Test func theRulesMatchTheDatabase() {
        #expect(UsernameRules.problem(with: "piero.ciobanu") == nil)
        #expect(UsernameRules.problem(with: "@Piero_C") == nil)
        #expect(UsernameRules.normalised("  @Piero_C ") == "piero_c")
        #expect(UsernameRules.problem(with: "pc") == "A username needs at least 3 characters.")
        #expect(UsernameRules.problem(with: String(repeating: "a", count: 21)) == "A username can be at most 20 characters.")
        #expect(UsernameRules.problem(with: "piero ciobanu") == "Use only letters, numbers, full stops and underscores.")
        #expect(UsernameRules.problem(with: "piero!") == "Use only letters, numbers, full stops and underscores.")
        #expect(UsernameRules.problem(with: ".piero") == "A username can’t start or end with a full stop.")
        #expect(UsernameRules.problem(with: "piero.") == "A username can’t start or end with a full stop.")
    }

    @Test func aSuggestionComesFromTheName() {
        #expect(UsernameRules.suggestion(from: "Piero Ciobanu") == "piero.ciobanu")
        #expect(UsernameRules.suggestion(from: "Zoë O’Brien") == "zoe.o.brien")
        #expect(UsernameRules.suggestion(from: "Alexandra-Catherine Montgomery") == "alexandra.catherine")
        #expect(UsernameRules.suggestion(from: "李") == "rower")
        #expect(UsernameRules.problem(with: UsernameRules.suggestion(from: "Kate Simmons")) == nil)
    }

    @Test func theSignInBoxTellsAnEmailFromAUsername() {
        #expect(UsernameRules.isEmail("piero@uea.ac.uk"))
        #expect(!UsernameRules.isEmail("piero.ciobanu"))
        #expect(!UsernameRules.isEmail("@piero"))
    }

    /// Choose a username, and Sign in with "Email or username"; hosted in a window to draw as on a phone.
    @Test func theScreensRender() throws {
        let width: CGFloat = 393
        let screens = HStack(spacing: 0) {
            ChooseUsernameView(name: "Piero Ciobanu") {}.frame(width: width, height: 760)
            SignInView().frame(width: width, height: 760)
        }
        .background(Tokens.Base.ground)
        .environment(\.colorScheme, .dark)
        let host = UIHostingController(rootView: screens)
        let size = CGSize(width: width * 2, height: 760)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = host
        window.makeKeyAndVisible()
        for _ in 0..<8 { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("username-screens-dark.png")
        try #require(image.pngData()).write(to: url)
        print("Username screens: \(url.path)")
        window.isHidden = true
    }
}
