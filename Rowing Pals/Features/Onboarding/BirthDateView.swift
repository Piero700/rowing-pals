//
//  BirthDateView.swift
//  Rowing Pals
//

import SwiftUI

/// "Your date of birth" (decision 107), asked once of an account that hasn't given one, before
/// anything else. There's no skipping it: Rowing Pals is for people 13 and over. Someone under 13
/// can change the date or delete the account.
struct BirthDateView: View {
    let onDone: () -> Void

    @State private var viewModel = BirthDateViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                Text("Your date of birth")
                    .textStyle(Typography.bigResult)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, Tokens.Spacing.group)
                // Needed to answer the question, so never hidden as helper text.
                Text("Rowing Pals is for people 13 and over. Only you and your club’s coaches can see it, and under 18 your account starts private.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)

                DatePicker(
                    "Date of birth",
                    selection: Binding(get: { viewModel.birthDate }, set: { viewModel.pick($0) }),
                    in: AgeRules.earliestBirthDate()...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .glassSurface(cornerRadius: Tokens.Radius.card)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                }

                Button {
                    Task { if await viewModel.save() { onDone() } }
                } label: {
                    if viewModel.isSaving || viewModel.isDeleting {
                        ProgressView().tint(Tokens.Ink.onBrand)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(.rpPrimary)
                .disabled(!viewModel.canContinue)
                .padding(.top, Tokens.Spacing.tight)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, Tokens.Spacing.group)
        }
        .scrollIndicators(.hidden)
        .background(Tokens.Base.ground)
        .alert(AgeRules.tooYoungMessage, isPresented: $viewModel.isShowingTooYoung) {
            Button("Change date", role: .cancel) {}
            Button("Delete my account", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
        } message: {
            Text("If the date is right, your account and everything in it will be deleted. This can't be undone.")
        }
    }
}
