//
//  ReviewVisibilityPicker.swift
//  Rowing Pals
//

import SwiftUI

/// Who can see this post, chosen on Review session. Defaults to Everyone (`PostVisibility`) — club
/// and friends combined, the widest of the three.
struct ReviewVisibilityPicker: View {
    let viewModel: ReviewSheetViewModel

    var body: some View {
        let selection = Binding<Int>(
            get: { PostVisibility.allCases.firstIndex(of: viewModel.visibility) ?? 0 },
            set: { viewModel.visibility = PostVisibility.allCases[$0] }
        )
        VStack(alignment: .leading, spacing: 6) {
            PillSegmentedControl(options: PostVisibility.allCases.map(\.label), selection: selection)
            // Friends means both ways now (decision 95), which the word alone doesn't say.
            Text("Friends: people you follow who follow you back.")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .guidance()
        }
    }
}
