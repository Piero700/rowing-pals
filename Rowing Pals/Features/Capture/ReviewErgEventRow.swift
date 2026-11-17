//
//  ReviewErgEventRow.swift
//  Rowing Pals
//

import SwiftUI

/// An erg event that's on (decision 91), on Review session: "Count for Club 2k day" when the main
/// piece is its piece; otherwise what to post to count for it.
struct ReviewErgEventRow: View {
    @Bindable var viewModel: ReviewSheetViewModel

    var body: some View {
        if let event = viewModel.matchingEvent {
            ToggleCard(title: "Count for \(event.title)",
                       detail: "Your \(event.pieceLabel) goes on the event’s board.",
                       isOn: $viewModel.countsForEvent)
                .padding(.top, Tokens.Spacing.loose)
        } else if let event = viewModel.openEvents.first {
            Text(viewModel.isManual
                 ? "\(event.title) is on, but manual entries can’t count for it: the numbers can’t be checked against a monitor photo."
                 : "\(event.title) is on: make a \(event.pieceLabel) your main piece to count it for the event.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, Tokens.Spacing.loose)
        }
    }
}
