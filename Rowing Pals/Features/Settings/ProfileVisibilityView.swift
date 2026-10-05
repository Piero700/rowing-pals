//
//  ProfileVisibilityView.swift
//  Rowing Pals
//

import SwiftUI

/// Settings → Profile visibility (SettingsPrivacy, decisions 34 and 36): Public or Private,
/// saved the moment it's chosen, and a note that the club's coaches always see the rower's
/// training, age and bodyweight whichever they choose.
struct ProfileVisibilityView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsGroup(
                    title: nil,
                    footnote: "You can change this at any time. Existing followers keep access if you go private. Your club’s coaches always see your training, age and bodyweight, whichever you choose."
                ) {
                    choice(
                        title: "Public",
                        detail: "Anyone can follow you and see your profile.",
                        isSelected: !viewModel.isPrivate
                    ) { Task { await viewModel.setPrivate(false) } }
                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                    choice(
                        title: "Private",
                        detail: "Only followers you approve see your posts.",
                        isSelected: viewModel.isPrivate
                    ) { Task { await viewModel.setPrivate(true) } }
                }
                .padding(.top, Tokens.Spacing.tight)
                .disabled(viewModel.isSavingPrivacy)

                if let error = viewModel.saveError {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Profile visibility") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func choice(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(detail)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Accent.brand)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .frame(minHeight: Tokens.Size.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
