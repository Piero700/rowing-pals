//
//  TestsView.swift
//  Rowing Pals
//

import SwiftUI

struct TestsView: View {
    var body: some View {
        NavigationStack {
            Text("Tests")
                .textStyle(Typography.displayNumeral)
                .foregroundStyle(Tokens.Ink.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Base.ground)
        }
    }
}

#Preview {
    TestsView()
}
