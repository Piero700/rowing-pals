//
//  Guidance.swift
//  Rowing Pals
//

import SwiftUI

/// Helper text (decision 98): one switch for the whole app. The app root works out whether
/// helper text shows (`GuidanceRules`) and puts it in the environment; any view marks a piece of
/// text, a note or a hint as guidance with `.guidance()`, and it leaves the layout entirely — no
/// gap where it was — once the person has used the app on 7 days, or turned it off in Settings.
///
/// Only explanations are guidance. Errors, facts about what's on screen ("Nobody is in this
/// squad yet.") and anything needed to use a screen are never marked.
enum GuidanceStore {
    /// The local days the app has been opened on, comma-separated (at most 7 are kept).
    static let daysKey = "guidanceOpenedDays"
    /// The person's own choice: "" until they choose, then "on" or "off".
    static let choiceKey = "guidanceChoice"
}

extension EnvironmentValues {
    /// Whether helper and guidance text shows. True by default, so previews and anything outside the
    /// app root show it.
    @Entry var showsGuidance: Bool = true
}

/// Removes guidance from the layout when helper text is off.
struct GuidanceModifier: ViewModifier {
    @Environment(\.showsGuidance) private var showsGuidance

    func body(content: Content) -> some View {
        if showsGuidance {
            content
        }
    }
}

extension View {
    /// Marks this view as helper text: it shows only while helper text is on (decision 98). Put it
    /// last, after the view's own padding, so the padding goes with it.
    func guidance() -> some View {
        modifier(GuidanceModifier())
    }
}

/// A fact with a hint after it, as one line of text: "No workouts yet." always shows; "Tap + to set
/// one…" only while helper text is on (decision 98). For empty states, whose fact must stay.
/// Style it like a `Text` (`.textStyle`, `.foregroundStyle`).
struct GuidedText: View {
    let fact: String
    let hint: String
    @Environment(\.showsGuidance) private var showsGuidance

    init(_ fact: String, hint: String) {
        self.fact = fact
        self.hint = hint
    }

    var body: some View {
        Text(showsGuidance ? "\(fact) \(hint)" : fact)
    }
}
