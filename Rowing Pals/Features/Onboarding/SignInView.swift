//
//  SignInView.swift
//  Rowing Pals
//

import SwiftUI

/// Email sign-up and sign-in. On sign-up, inserts the new `profiles` row —
/// see `SignInViewModel`. Static design pass only; club selection and the
/// Novice/Senior picker arrive with task 06.
struct SignInView: View {
    @State private var viewModel = SignInViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password, displayName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.isSigningUp ? "Create your account" : "Sign in")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("Your feed, leaderboards and squad live here.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 10) {
                    if viewModel.isSigningUp {
                        field("Display name", text: $viewModel.displayName, field: .displayName)
                    }
                    field("Email", text: $viewModel.email, field: .email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    field("Password", text: $viewModel.password, field: .password, isSecure: true)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Accent.live)
                }

                Button {
                    focusedField = nil
                    Task { await viewModel.submit() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView().tint(Tokens.Base.dark)
                        } else {
                            Text(viewModel.isSigningUp ? "Sign up" : "Sign in")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Spacer()
                    }
                    .foregroundStyle(Tokens.Base.dark)
                    .padding(.vertical, 15)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Tokens.Accent.signal)
                    }
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.5)

                Button {
                    viewModel.isSigningUp.toggle()
                    viewModel.errorMessage = nil
                } label: {
                    Text(viewModel.isSigningUp
                        ? "Already have an account? Sign in"
                        : "New here? Create an account")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Accent.signal)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .background(Tokens.Base.ground)
    }

    private var canSubmit: Bool {
        guard !viewModel.email.isEmpty, !viewModel.password.isEmpty else { return false }
        if viewModel.isSigningUp && viewModel.displayName.isEmpty { return false }
        return !viewModel.isLoading
    }

    private func field(_ placeholder: String, text: Binding<String>, field: Field, isSecure: Bool = false) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textStyle(Typography.body)
        .foregroundStyle(Tokens.Ink.primary)
        .focused($focusedField, equals: field)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .glassSurface(cornerRadius: 18)
    }
}

#Preview {
    SignInView()
}
