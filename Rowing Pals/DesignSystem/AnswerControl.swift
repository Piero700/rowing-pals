//
//  AnswerControl.swift
//  Rowing Pals
//

import SwiftUI

/// Available · Can't (decision 68): a rower's answer to a session, a whole day or a race, as the
/// compact glass segmented control. Nothing is chosen until they answer; once a session has
/// started it shows the answer but can't change.
struct AnswerControl: View {
    let answer: PracticeAnswer?
    var isEnabled = true
    /// Fills the width instead of the calendar's fixed column (the practice page).
    var isWide = false
    let onChange: (PracticeAnswer) -> Void

    var body: some View {
        PillSegmentedControl(
            options: PracticeAnswer.allCases.map(\.label),
            selection: Binding(
                get: { answer.flatMap { PracticeAnswer.allCases.firstIndex(of: $0) } ?? -1 },
                set: { onChange(PracticeAnswer.allCases[$0]) }
            ),
            compact: true
        )
        .frame(width: isWide ? nil : Tokens.Schedule.answerControlWidth)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}
