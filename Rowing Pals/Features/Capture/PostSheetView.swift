//
//  PostSheetView.swift
//  Rowing Pals
//

import SwiftUI

/// The sheet presented from the Post tab. A NavigationStack scoped to this
/// sheet is safe — it doesn't affect the tab content's own scroll-to-minimise
/// behaviour, since the sheet isn't part of that view hierarchy.
struct PostSheetView: View {
    /// The workout chosen on its Feed card, if Log was opened from one (decision 57).
    var workoutId: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // Passed explicitly rather than letting ReviewSheetView resolve
            // its own @Environment(\.dismiss): it's pushed onto this same
            // NavigationStack via navigationDestination, so its own dismiss
            // would only pop back to CaptureView, not close this sheet.
            CaptureView(workoutId: workoutId, onPosted: { dismiss() }, onClose: { dismiss() })
                // Swipe from the left edge to close Log, like going back (decision 61).
                .edgeSwipeToDismiss()
        }
    }
}

#Preview {
    PostSheetView()
}
