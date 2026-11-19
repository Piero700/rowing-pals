//
//  ActivityShareSheet.swift
//  Rowing Pals
//

import SwiftUI
import UIKit

/// The iPhone share screen for several items at once. `ShareLink` takes one item, and the shared
/// week picture goes with its link together (decision 110).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
