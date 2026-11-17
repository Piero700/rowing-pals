//
//  ReviewSessionTypeSection.swift
//  Rowing Pals
//

import SwiftUI

/// "Session type" on Review session: Training, or one of the standard tests. Choosing a test is what
/// records a test result; the distance must match the test exactly. A manual entry has none.
struct ReviewSessionTypeSection: View {
    @Bindable var viewModel: ReviewSheetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            if viewModel.showsTestPrompt, let test = viewModel.detectedTest {
                ReviewTestBanner(test: test, viewModel: viewModel)
            }

            if !viewModel.isManual {
                VStack(alignment: .leading, spacing: 6) {
                    ReviewFieldLabel(text: "Session type")
                    Menu {
                        Picker("Session type", selection: $viewModel.sessionKind) {
                            ForEach(viewModel.availableKinds) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                    } label: {
                        ReviewMenuRow(text: viewModel.sessionKind.label)
                    }
                    if let problem = viewModel.sessionKindProblem {
                        Text(problem)
                            .textStyle(Typography.bodySecondary)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
            }
        }
    }
}
