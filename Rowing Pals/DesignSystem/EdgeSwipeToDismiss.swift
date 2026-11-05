//
//  EdgeSwipeToDismiss.swift
//  Rowing Pals
//

import SwiftUI

/// Mimics `NavigationStack`'s interactive edge-swipe-back gesture, for
/// screens presented via `.sheet`/`.fullScreenCover` instead — which don't
/// get that gesture for free. Used where a feed tab's screen would
/// otherwise need wrapping in a `NavigationStack` to get it natively, which
/// breaks that tab's `.tabBarMinimizeBehavior(.onScrollDown)` (a tab's root
/// `ScrollView` has to be a *direct* child of the tab's content — see
/// RootView's own note on this).
///
/// Decision 61 (swipe back everywhere): `RouteHost` and the Log screen put this on the root of
/// every full-screen area, so any screen shown that way can be swiped away, now and in future.
/// Who takes the swipe is read from where the screen actually sits (`PresentationProbe`):
/// - a pushed screen leaves it to its navigation stack (`SwipeBackNavigation`);
/// - otherwise the outermost `edgeSwipeToDismiss()` in each presentation takes it, and any inside
///   it in the same presentation do nothing;
/// - a cover or sheet opened from anywhere is a new presentation, so its own `edgeSwipeToDismiss()`
///   works again (2026-11-05: PB history opened from a pushed rower profile didn't swipe away).
private struct EdgeSwipeToDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    /// The presentation whose swipe an outer `edgeSwipeToDismiss()` already handles.
    @Environment(\.swipeBackPresentation) private var handledPresentation
    @State private var place: PresentationPlace?
    @State private var dragOffset: CGFloat = 0

    private let edgeWidth = Tokens.Size.swipeBackEdge
    private let dismissThreshold: CGFloat = 100
    /// Comfortably wider than any device — the offset needed to carry the
    /// view fully off-screen to the right regardless of actual width.
    private let offscreenOffset: CGFloat = 600

    /// Until UIKit has placed the screen nothing takes the swipe.
    private var isActive: Bool {
        guard let place else { return false }
        return !place.isPushed && place.presentation != handledPresentation
    }

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { value in
                        guard isActive, value.startLocation.x <= edgeWidth, value.translation.width > 0 else { return }
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard isActive, value.startLocation.x <= edgeWidth else { return }
                        if value.translation.width > dismissThreshold {
                            // Finish the slide-right under our own animation
                            // *before* calling dismiss() - otherwise
                            // .fullScreenCover's own (vertical) dismiss
                            // transition starts at the same moment as this
                            // offset snapping back to 0, and the two fight
                            // visibly.
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragOffset = offscreenOffset
                            } completion: {
                                dismiss()
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                        }
                    },
                // Off when inactive, not just ignored: a live drag here would claim the touch
                // before a pushed screen's own swipe back could start. A mask, not an `if`, so
                // the screen's view tree (and its state) stays the same either way.
                including: isActive ? .all : .subviews
            )
            .background(PresentationProbe { newPlace in
                if place != newPlace { place = newPlace }
            })
            .environment(\.swipeBackPresentation, isActive ? place?.presentation : handledPresentation)
    }
}

extension View {
    func edgeSwipeToDismiss() -> some View {
        modifier(EdgeSwipeToDismiss())
    }
}

private struct SwipeBackPresentationKey: EnvironmentKey {
    static let defaultValue: ObjectIdentifier? = nil
}

extension EnvironmentValues {
    /// The presentation whose swipe back an outer `edgeSwipeToDismiss()` already handles
    /// (decision 61).
    var swipeBackPresentation: ObjectIdentifier? {
        get { self[SwipeBackPresentationKey.self] }
        set { self[SwipeBackPresentationKey.self] = newValue }
    }
}
