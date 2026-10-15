//
//  SignInView.swift
//  Rowing Pals
//

import AuthenticationServices
import SwiftUI

/// Signing in and up (decision 66): email and password with **Forgot password?**, a 6-digit
/// code to confirm a new account's email, and **Sign in with Apple** or **Continue with Google**
/// so nobody needs a password. The `profiles` row is written on the first session — see
/// `SignInViewModel`.
struct SignInView: View {
    @State private var viewModel = SignInViewModel()
    @FocusState private var focusedField: Field?
    @State private var isShowingTerms = false
    @Environment(\.colorScheme) private var colorScheme

    private enum Field {
        case email, password, displayName, code, newPassword
    }

    var body: some View {
        // Each step slides in whole, like a pushed screen, rather than cross-fading.
        ZStack {
            page
                .id(viewModel.step)
                .transition(.push(from: .trailing))
        }
        .animation(.snappy, value: viewModel.step)
        .background(Tokens.Base.ground)
        .sheet(isPresented: $isShowingTerms) {
            TermsOfServiceView(onAgree: { viewModel.hasAgreedToTerms = true })
        }
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.step != .signIn {
                    GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") {
                        focusedField = nil
                        back()
                    }
                }
                header
                    .padding(.top, viewModel.step == .signIn ? 32 : 0)

                switch viewModel.step {
                case .signIn, .signUp: credentials
                case .verifyEmail: verifyEmail
                case .forgotEmail: forgotEmail
                case .forgotCode: forgotCode
                }

                if let notice = viewModel.noticeMessage {
                    Text(notice)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.System.error)
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
    }

    private func back() {
        switch viewModel.step {
        case .forgotCode: viewModel.go(to: .forgotEmail)
        case .verifyEmail: viewModel.go(to: .signUp)
        default: viewModel.go(to: .signIn)
        }
    }

    // MARK: - Header

    private var title: String {
        switch viewModel.step {
        case .signIn: "Sign in"
        case .signUp: "Create your account"
        case .verifyEmail: "Check your email"
        case .forgotEmail: "Reset your password"
        case .forgotCode: "Choose a new password"
        }
    }

    private var subtitle: String {
        let email = viewModel.email.trimmingCharacters(in: .whitespaces)
        switch viewModel.step {
        case .signIn, .signUp: return "Your feed, leaderboards and squad live here."
        case .verifyEmail: return "We've sent a code to \(email). Enter it to confirm your email and start."
        case .forgotEmail: return "Enter your account's email and we'll send you a code to reset your password."
        case .forgotCode: return "Enter the code we sent to \(email), then your new password."
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(Typography.bigResult)
                .foregroundStyle(Tokens.Ink.primary)
            Text(subtitle)
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }

    // MARK: - Sign in / sign up

    @ViewBuilder
    private var credentials: some View {
        VStack(spacing: 10) {
            if viewModel.isSigningUp {
                field("Display name", text: $viewModel.displayName, field: .displayName)
                    .textContentType(.name)
            }
            field("Email", text: $viewModel.email, field: .email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.username)
            field("Password", text: $viewModel.password, field: .password, isSecure: true)
                .textContentType(viewModel.isSigningUp ? .newPassword : .password)
        }

        if viewModel.step == .signIn {
            HStack {
                Spacer()
                Button("Forgot password?") {
                    focusedField = nil
                    viewModel.go(to: .forgotEmail)
                }
                .buttonStyle(.rpText)
                .textStyle(Typography.bodySecondary)
            }
            .padding(.top, -12)
        }

        if viewModel.isSigningUp {
            termsAgreementRow
        }

        primaryButton(viewModel.isSigningUp ? "Sign up" : "Sign in", isEnabled: canSubmit) {
            await viewModel.submit()
        }

        orDivider
        socialButtons

        Button {
            viewModel.go(to: viewModel.isSigningUp ? .signIn : .signUp)
        } label: {
            Text(viewModel.isSigningUp ? "Already have an account? Sign in" : "New here? Create an account")
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Accent.brand)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.minTap)
        }
    }

    private var orDivider: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            Rectangle().fill(Tokens.Surface.line).frame(height: 1)
            Text("or")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
            Rectangle().fill(Tokens.Surface.line).frame(height: 1)
        }
    }

    /// Apple's own button (its required look), then Google; and what continuing agrees to.
    private var socialButtons: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(viewModel.isSigningUp ? .signUp : .signIn) { request in
                viewModel.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await viewModel.finishApple(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: Tokens.Size.primaryButton)
            .clipShape(Capsule())
            .disabled(viewModel.isLoading)

            Button {
                focusedField = nil
                Task { await viewModel.signInWithGoogle() }
            } label: {
                Text("Continue with Google")
            }
            .buttonStyle(.rpGlass)
            .disabled(viewModel.isLoading)

            (Text("By continuing with Apple or Google you agree to the ")
                + Text("Terms of Service").underline().foregroundColor(Tokens.Accent.brand)
                + Text("."))
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { isShowingTerms = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the Terms of Service")
        }
    }

    private var termsAgreementRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                viewModel.hasAgreedToTerms.toggle()
            } label: {
                Image(systemName: viewModel.hasAgreedToTerms ? "checkmark.square.fill" : "square")
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(viewModel.hasAgreedToTerms ? Tokens.Accent.brand : Tokens.Ink.secondary)
                    .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Agree to the Terms of Service")
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                Text("I agree to the ")
                    .foregroundStyle(Tokens.Ink.primary)
                Button {
                    isShowingTerms = true
                } label: {
                    Text("Terms of Service")
                        .underline()
                        .foregroundStyle(Tokens.Accent.brand)
                        .frame(minHeight: Tokens.Size.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .textStyle(Typography.bodySecondary)

            Spacer()
        }
    }

    private var canSubmit: Bool {
        guard !viewModel.email.isEmpty, !viewModel.password.isEmpty else { return false }
        if viewModel.isSigningUp {
            if viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty || !viewModel.hasAgreedToTerms { return false }
            if viewModel.password.count < SignInViewModel.minimumPasswordLength { return false }
        }
        return !viewModel.isLoading
    }

    // MARK: - Confirm email

    @ViewBuilder
    private var verifyEmail: some View {
        codeField
        primaryButton("Confirm email", isEnabled: viewModel.isCodeComplete && !viewModel.isLoading) {
            await viewModel.verifyCode()
        }
        resendButton
        Text("Can't find it? Check your junk folder. The code works for an hour.")
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
    }

    // MARK: - Forgot password

    @ViewBuilder
    private var forgotEmail: some View {
        field("Email", text: $viewModel.email, field: .email)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.username)
        primaryButton("Send code", isEnabled: viewModel.email.contains("@") && !viewModel.isLoading) {
            await viewModel.sendResetCode()
        }
    }

    @ViewBuilder
    private var forgotCode: some View {
        codeField
        field("New password", text: $viewModel.newPassword, field: .newPassword, isSecure: true)
            .textContentType(.newPassword)
        if !viewModel.newPassword.isEmpty && viewModel.newPassword.count < SignInViewModel.minimumPasswordLength {
            Text("At least \(SignInViewModel.minimumPasswordLength) characters.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        primaryButton(
            "Set new password",
            isEnabled: viewModel.isCodeComplete && viewModel.newPassword.count >= SignInViewModel.minimumPasswordLength
                && !viewModel.isLoading
        ) {
            await viewModel.resetPassword()
        }
        resendButton
    }

    // MARK: - Building blocks

    private var codeField: some View {
        TextField("Code", text: $viewModel.code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedField, equals: .code)
            .onChange(of: viewModel.code) { _, new in
                let clean = String(new.filter(\.isWholeNumber).prefix(SignInViewModel.codeLengths.upperBound))
                if clean != new { viewModel.code = clean }
            }
            .textStyle(Typography.reviewResult)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(minHeight: Tokens.Size.primaryButton + Tokens.Spacing.loose)
            .glassSurface(cornerRadius: Tokens.Radius.input)
            .onAppear { focusedField = .code }
    }

    private var resendButton: some View {
        Button("Resend code") { Task { await viewModel.resendCode() } }
            .buttonStyle(.rpText)
            .textStyle(Typography.bodySecondary)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isLoading)
    }

    private func primaryButton(_ title: String, isEnabled: Bool, action: @escaping () async -> Void) -> some View {
        Button {
            focusedField = nil
            Task { await action() }
        } label: {
            if viewModel.isLoading {
                ProgressView().tint(Tokens.Ink.onBrand)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(!isEnabled)
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
        .frame(height: Tokens.Size.input)
        .glassSurface(cornerRadius: Tokens.Radius.input)
    }
}

#Preview {
    SignInView()
}
