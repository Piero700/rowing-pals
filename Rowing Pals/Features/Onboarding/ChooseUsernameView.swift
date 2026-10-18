//
//  ChooseUsernameView.swift
//  Rowing Pals
//

import SwiftUI

/// "Choose a username" (decision 85), for an account that hasn't got one: what it's for, the field
/// with a suggestion from their name, whether it's free, and Continue. There's no skipping it —
/// every account has a username.
struct ChooseUsernameView: View {
    let onDone: () -> Void

    @State private var viewModel: ChooseUsernameViewModel
    @FocusState private var isFocused: Bool

    init(name: String, onDone: @escaping () -> Void) {
        self.onDone = onDone
        _viewModel = State(initialValue: ChooseUsernameViewModel(name: name))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                Text("Choose a username")
                    .textStyle(Typography.bigResult)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, Tokens.Spacing.group)
                Text("It shows as @username on your profile, people can find you by it, and you can sign in with it instead of your email.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)

                HStack(spacing: 2) {
                    Text("@")
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.secondary)
                    TextField("username", text: $viewModel.username)
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.primary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .focused($isFocused)
                        .submitLabel(.done)
                }
                .padding(.horizontal, Tokens.Spacing.card)
                .frame(height: Tokens.Size.input)
                .glassSurface(cornerRadius: Tokens.Radius.input)
                .padding(.top, Tokens.Spacing.tight)
                .task(id: viewModel.username) {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await viewModel.check()
                }

                Text(viewModel.note ?? "Letters, numbers, full stops and underscores; 3 to 20 characters.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(viewModel.note == nil ? Tokens.Ink.secondary
                                     : (viewModel.isFree ? Tokens.Accent.success : Tokens.System.error))
                    .padding(.horizontal, 4)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                }

                Button {
                    Task { if await viewModel.save() { onDone() } }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(Tokens.Ink.onBrand)
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(.rpPrimary)
                .disabled(!viewModel.canContinue)
                .padding(.top, Tokens.Spacing.tight)

                Text("You can change it later in Edit profile.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Tokens.Base.ground)
        .onAppear { isFocused = true }
    }
}
