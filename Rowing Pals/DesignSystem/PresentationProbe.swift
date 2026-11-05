//
//  PresentationProbe.swift
//  Rowing Pals
//

import SwiftUI
import UIKit

/// Tells a view where it sits in UIKit: which presentation (the tabs, a full-screen cover, a sheet)
/// it belongs to, and whether it was pushed onto a navigation stack. `edgeSwipeToDismiss()` uses it
/// to decide who takes the swipe back (decision 61). SwiftUI passes its environment into covers it
/// presents, so an environment flag alone can't tell a pushed screen from a cover opened over it.
struct PresentationProbe: UIViewRepresentable {
    let onChange: (PresentationPlace) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.onChange = onChange
        uiView.report()
    }

    final class ProbeView: UIView {
        var onChange: ((PresentationPlace) -> Void)?
        private var lastPlace: PresentationPlace?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        func report() {
            guard window != nil, let place = currentPlace(), place != lastPlace else { return }
            lastPlace = place
            // Never change SwiftUI state in the middle of its own update.
            DispatchQueue.main.async { [weak self] in self?.onChange?(place) }
        }

        /// The first navigation stack above this view says whether it was pushed; the controller at
        /// the very top (no parent) is the presentation it belongs to.
        private func currentPlace() -> PresentationPlace? {
            var responder: UIResponder? = self
            while let next = responder, !(next is UIViewController) {
                responder = next.next
            }
            guard var controller = responder as? UIViewController else { return nil }
            var isPushed: Bool?
            while let parent = controller.parent {
                if isPushed == nil, let navigation = parent as? UINavigationController {
                    let index = navigation.viewControllers.firstIndex { $0 === controller }
                    isPushed = (index ?? 0) > 0
                }
                controller = parent
            }
            return PresentationPlace(presentation: ObjectIdentifier(controller), isPushed: isPushed ?? false)
        }
    }
}
