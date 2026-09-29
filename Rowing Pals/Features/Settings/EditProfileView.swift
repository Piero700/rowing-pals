//
//  EditProfileView.swift
//  Rowing Pals
//

import SwiftUI

/// Settings → Account → Edit profile (v3 moves these fields off the main Settings list): display
/// name, gender, level and weekly target, saved with Save changes.
struct EditProfileView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                label("Display name")
                TextField("Your name", text: $viewModel.displayName)
                    .textStyle(Typography.bodyV3)
                    .focused($isNameFocused)
                    .padding(.horizontal, 14)
                    .frame(minHeight: Tokens.Size.input)
                    .background(field.fill(Tokens.Surface.card))
                    .overlay { field.strokeBorder(Tokens.Surface.line, lineWidth: 1) }

                label("Gender")
                PillSegmentedControl(options: ["Male", "Female"], selection: Binding(
                    get: { viewModel.gender == .female ? 1 : 0 },
                    set: { viewModel.gender = $0 == 1 ? .female : .male }
                ))

                label("Level")
                PillSegmentedControl(options: ["Novice", "Senior"], selection: Binding(
                    get: { viewModel.category == .senior ? 1 : 0 },
                    set: { viewModel.category = $0 == 1 ? .senior : .novice }
                ))
                Text("Novice means you're in your first season. You can change this any time.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)

                label("Weekly target")
                HStack {
                    Text(viewModel.weeklyTargetM.formattedMetres)
                        .textStyle(Typography.metricValue)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    Spacer()
                    Stepper("Weekly target", value: $viewModel.weeklyTargetM, in: 0...50_000, step: 1_000)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: Tokens.Size.input)
                .background(field.fill(Tokens.Surface.card))
                .overlay { field.strokeBorder(Tokens.Surface.line, lineWidth: 1) }

                if let saveError = viewModel.saveError {
                    Text(saveError)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }

                Button {
                    isNameFocused = false
                    Task {
                        await viewModel.save()
                        if viewModel.saveError == nil { dismiss() }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(Tokens.Ink.onBrand)
                    } else {
                        Text("Save changes")
                    }
                }
                .buttonStyle(.rpPrimary)
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                .padding(.top, Tokens.Spacing.gap)
            }
            .padding(Tokens.Spacing.screen)
        }
        .background(Tokens.Base.ground)
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .dismissesKeyboardOnTap()
    }

    private var field: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.top, 4)
    }
}
