//
//  EditProfileHost.swift
//  Rowing Pals
//

import SwiftUI

/// Edit profile on its own, as the coach's Profile opens it (decision 67): loads the profile, then
/// shows the same screen Settings → Edit profile does.
struct EditProfileHost: View {
    @State private var viewModel = SettingsViewModel()
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if hasLoaded {
                EditProfileView(viewModel: viewModel)
            } else {
                ProgressView()
                    .tint(Tokens.Ink.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Tokens.Base.ground)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .task {
            await viewModel.load()
            hasLoaded = true
        }
    }
}
