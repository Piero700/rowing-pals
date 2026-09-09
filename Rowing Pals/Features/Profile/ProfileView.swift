//
//  ProfileView.swift
//  Rowing Pals
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Text("Profile")
                .textStyle(Typography.displayNumeral)
                .foregroundStyle(Tokens.Ink.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Base.ground)
        }
    }
}

#Preview {
    ProfileView()
}
