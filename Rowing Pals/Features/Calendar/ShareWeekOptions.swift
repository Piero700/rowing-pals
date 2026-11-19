//
//  ShareWeekOptions.swift
//  Rowing Pals
//

import SwiftUI

/// "Which week" and "Who for" on the Share week sheet, as one grouped card (decision 110).
struct ShareWeekOptions: View {
    @Bindable var viewModel: ShareWeekViewModel

    var body: some View {
        GroupedSection {
            GroupedRow(label: "Which week") {
                Menu {
                    Picker("Which week", selection: $viewModel.which) {
                        Text(ShareWeekViewModel.Which.thisWeek.label).tag(ShareWeekViewModel.Which.thisWeek)
                        Text(ShareWeekViewModel.Which.nextWeek.label).tag(ShareWeekViewModel.Which.nextWeek)
                    }
                } label: {
                    GroupedValue(text: viewModel.which.label)
                }
            }
            GroupedDivider()
            GroupedRow(label: "Who for") {
                Menu {
                    Picker("Who for", selection: $viewModel.audience) {
                        Text("Whole club").tag(ShareAudience.club)
                        ForEach(viewModel.squads) { squad in
                            Text(squad.name).tag(ShareAudience.squad(squad.id))
                        }
                    }
                } label: {
                    GroupedValue(text: viewModel.audienceLabel)
                }
            }
        }
    }
}
