//
//  MetresView.swift
//  Rowing Pals
//

import SwiftUI

struct MetresView: View {
    var body: some View {
        NavigationStack {
            Text("Metres")
                .textStyle(Typography.displayNumeral)
                .foregroundStyle(Tokens.Ink.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Base.ground)
        }
    }
}

#Preview {
    MetresView()
}
