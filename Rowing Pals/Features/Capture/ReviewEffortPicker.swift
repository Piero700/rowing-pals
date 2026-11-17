//
//  ReviewEffortPicker.swift
//  Rowing Pals
//

import SwiftUI

/// How hard the session felt, on the 0–10 scale. Optional; it sharpens the rower's predictions.
struct ReviewEffortPicker: View {
    @Bindable var viewModel: ReviewSheetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ReviewFieldLabel(text: "How hard did it feel? (optional)")
            Menu {
                Picker("How hard did it feel?", selection: $viewModel.rpe) {
                    Text("Not rated").tag(Int?.none)
                    ForEach(0...10, id: \.self) { value in
                        Text(Self.title(value)).tag(Int?.some(value))
                    }
                }
            } label: {
                ReviewMenuRow(text: viewModel.rpe.map(Self.title) ?? "Not rated")
            }
        }
        .padding(.top, Tokens.Spacing.gap)
    }

    /// The Borg CR10 scale's words for each point.
    private static func title(_ value: Int) -> String {
        let words = ["Rest", "Very easy", "Easy", "Moderate", "Somewhat hard", "Hard",
                     "Hard", "Very hard", "Very hard", "Extremely hard", "Maximal"]
        return "\(value) · \(words[value])"
    }
}
