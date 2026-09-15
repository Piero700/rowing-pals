//
//  PostSheetView.swift
//  Rowing Pals
//

import SwiftUI

/// The sheet presented from the Post tab. A NavigationStack scoped to this
/// sheet is safe — it doesn't affect the tab content's own scroll-to-minimise
/// behaviour, since the sheet isn't part of that view hierarchy.
struct PostSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // Passed explicitly rather than letting ReviewSheetView resolve
            // its own @Environment(\.dismiss): it's pushed onto this same
            // NavigationStack via navigationDestination, so its own dismiss
            // would only pop back to CaptureView, not close this sheet.
            CaptureView(onPosted: { dismiss() })
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
