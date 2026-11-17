//
//  ReviewZonePicker.swift
//  Rowing Pals
//

import SwiftUI

/// The training zone on Review session (decision 31): the badge on the main split and the intensity
/// the predictions work from. A test pre-selects AN; a test's badge stays the test's own name.
struct ReviewZonePicker: View {
    @Bindable var viewModel: ReviewSheetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ReviewFieldLabel(text: "Zone")
            Menu {
                Picker("Zone", selection: $viewModel.zone) {
                    ForEach(TrainingZone.allCases) { zone in
                        Text(zone.title).tag(zone)
                    }
                }
            } label: {
                ReviewMenuRow(text: viewModel.zone.title)
            }
            if viewModel.sessionKind.test != nil {
                Text("A test is an all-out effort, so AN is chosen. Change it if this wasn't flat out.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .guidance()
            }
        }
    }
}
