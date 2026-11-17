//
//  ReviewTrainedWithRow.swift
//  Rowing Pals
//

import SwiftUI

/// "Trained with" on Review session (decision 90): the clubmates tagged on this post, or an
/// invitation to tag them; opens the picker.
struct ReviewTrainedWithRow: View {
    let viewModel: ReviewSheetViewModel
    @State private var isTagging = false

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    var body: some View {
        let people = viewModel.taggedPeople
        Button {
            isTagging = true
            Task { await viewModel.loadClubmates() }
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                RPIconView(icon: .people, size: Tokens.Icon.detail)
                    .foregroundStyle(people.isEmpty ? Tokens.Ink.secondary : Tokens.Accent.brand)
                Text(people.isEmpty ? "Tag the clubmates you trained with"
                     : people.map(\.displayName).joined(separator: ", "))
                    .textStyle(Typography.bodyV3)
                    .foregroundStyle(people.isEmpty ? Tokens.Ink.secondary : Tokens.Ink.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(people.isEmpty ? "Add" : "Edit")
                    .textStyle(Typography.meta)
                    .fontWeight(.semibold)
                    .foregroundStyle(Tokens.Accent.brand)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.input, alignment: .leading)
            .background(Self.shape.fill(Tokens.Surface.card))
            .overlay { Self.shape.strokeBorder(Tokens.Surface.line, lineWidth: Tokens.Grouped.hairline) }
            .contentShape(Self.shape)
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(people.isEmpty ? "Trained with: nobody tagged. Add" : "Trained with \(people.map(\.displayName).joined(separator: ", ")). Edit")
        .sheet(isPresented: $isTagging) {
            CrewTagPicker(people: viewModel.clubmates, selected: Set(viewModel.taggedIds),
                          isLoading: viewModel.isLoadingClubmates) { chosen in
                viewModel.setTagged(chosen)
            }
        }
    }
}
