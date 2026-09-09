//
//  PostSheetView.swift
//  Rowing Pals
//

import SwiftUI

/// Placeholder sheet content presented from the Post tab. Real capture flow
/// arrives in tasks 07 and 08.
struct PostSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Post")
                .textStyle(Typography.displayNumeral)
                .foregroundStyle(Tokens.Ink.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Base.ground)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    PostSheetView()
}
