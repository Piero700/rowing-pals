//
//  TourRules.swift
//  Rowing Pals
//

import Foundation

/// The short first-run tour (decision 109): five cards over the real tab bar, one for each main
/// part of the rower version and of the coach version. Each version's tour shows once, the first
/// time that version opens while helper text is on (so a new account, not someone who has used the
/// app for a week or turned helper text off), and again whenever Settings → Help → Show the tour
/// again is tapped.
nonisolated enum TourRules {
    /// Per version, on this phone: "true" once the tour was finished or skipped.
    static func seenKey(_ mode: AppMode) -> String {
        switch mode {
        case .rowing: "tourSeenRowing"
        case .coaching: "tourSeenCoaching"
        }
    }

    /// Whether the tour starts by itself when the version opens.
    static func startsByItself(seen: Bool, showsGuidance: Bool) -> Bool {
        !seen && showsGuidance
    }

    /// The rower version's tour. A coach-only account has no Log button, so that card is left out.
    static func rowerSteps(showsLog: Bool = true) -> [TourStep] {
        var steps = [
            TourStep(target: .tab("Feed"), title: "Your club’s sessions",
                     body: "Sessions from your clubmates and the people you follow. React and comment on them."),
            TourStep(target: .newButton, title: "Log a session",
                     body: "Take a photo of the erg monitor after a piece. The app reads the time, distance, split and rate; check them, then post."),
            TourStep(target: .tab("Rankings"), title: "See where you stand",
                     body: "Your club’s volume, test results and challenges. Pieces at a test distance or time go on the leaderboards by themselves."),
            TourStep(target: .tab("Calendar"), title: "Your week",
                     body: "Practices, races and workouts your coaches set. Say whether you’re available."),
            TourStep(target: .tab("Profile"), title: "Your progress",
                     body: "Your personal bests, predicted 2k and 5k, and your streak. Settings are here too.")
        ]
        if !showsLog { steps.removeAll { $0.target == .newButton } }
        return steps
    }

    /// The coach version's tour.
    static let coachSteps: [TourStep] = [
        TourStep(target: .tab("Rowers"), title: "Your rowers",
                 body: "Every rower’s week at a glance: metres against their target, sessions, predicted 2k and anything worth a look."),
        TourStep(target: .tab("Workouts"), title: "Set workouts",
                 body: "The workouts you set and how each rower did. On the day, open the notepad to take down scores."),
        TourStep(target: .tab("Boats"), title: "Boats",
                 body: "Put crews in boats for water sessions, and save the crews you use again and again."),
        TourStep(target: .tab("Calendar"), title: "The club’s calendar",
                 body: "Practices and events, who’s available, and the register."),
        TourStep(target: .newButton, title: "Make something new",
                 body: "A land session, a water session or an announcement for the club.")
    ]

    static func steps(for mode: AppMode, showsLog: Bool = true) -> [TourStep] {
        switch mode {
        case .rowing: rowerSteps(showsLog: showsLog)
        case .coaching: coachSteps
        }
    }

    /// "2 of 5".
    static func progressText(index: Int, count: Int) -> String {
        "\(index + 1) of \(count)"
    }
}
