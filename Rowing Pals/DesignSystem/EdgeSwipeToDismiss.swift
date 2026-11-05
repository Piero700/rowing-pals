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
/// It applies once — a screen that also asks for it inside an area that already has it, or a
/// pushed screen (which the navigation stack's own swipe takes back), is left alone.
private struct EdgeSwipeToDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.swipeBackHandled) private var isHandled
    @State private var dragOffset: CGFloat = 0

    private let edgeWidth = Tokens.Size.swipeBackEdge
    private let dismissThreshold: CGFloat = 100
    /// Comfortably wider than any device — the offset needed to carry the
    /// view fully off-screen to the right regardless of actual width.
    private let offscreenOffset: CGFloat = 600

    @ViewBuilder
    func body(content: Content) -> some View {
        if isHandled {
            content
        } else {
            swipeable(content)
                .environment(\.swipeBackHandled, true)
        }
    }

    private func swipeable(_ content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { value in
                        guard value.startLocation.x <= edgeWidth, value.translation.width > 0 else { return }
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard value.startLocation.x <= edgeWidth else { return }
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
                    }
            )
    }
}

extension View {
    func edgeSwipeToDismiss() -> some View {
        modifier(EdgeSwipeToDismiss())
    }

    /// Marks a pushed screen: its stack's own swipe takes it back, so `edgeSwipeToDismiss()`
    /// inside it does nothing.
    func swipeBackHandledByStack() -> some View {
        environment(\.swipeBackHandled, true)
    }
}

private struct SwipeBackHandledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Something above already swipes this screen back (decision 61).
    var swipeBackHandled: Bool {
        get { self[SwipeBackHandledKey.self] }
        set { self[SwipeBackHandledKey.self] = newValue }
    }
}
