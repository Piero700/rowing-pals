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
private struct EdgeSwipeToDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    private let edgeWidth: CGFloat = 24
    private let dismissThreshold: CGFloat = 100

    func body(content: Content) -> some View {
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
                            dismiss()
                        }
                        withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    }
            )
    }
}

extension View {
    func edgeSwipeToDismiss() -> some View {
        modifier(EdgeSwipeToDismiss())
    }
}
