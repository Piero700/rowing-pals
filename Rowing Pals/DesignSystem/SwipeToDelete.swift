//
//  SwipeToDelete.swift
//  Rowing Pals
//

import SwiftUI
import UIKit

/// Swipe a card right to left to delete it, as iOS does for an alarm (decision 60, user
/// 2026-10-14; changed 2026-10-15): the swipe opens a red Delete button behind the card's
/// trailing edge and stops there — however far you swipe, nothing is deleted until you tap
/// Delete. Tap the card while it's open to close it.
///
/// `List`'s own `.swipeActions` only works inside a `List`, and the app's cards sit in scroll
/// views, so this uses a UIKit pan that only starts on a sideways swipe — the page still scrolls
/// up and down over the card, and a swipe the other way is left for going back.
private struct SwipeToDelete: ViewModifier {
    /// Deletes the item; true when it's gone.
    let onDelete: () async -> Bool

    @State private var offset: CGFloat = 0
    @State private var isOpen = false
    @State private var width: CGFloat = 0
    /// Delete was tapped: the card fades out where it is while it's deleted.
    @State private var isDeleting = false

    private var actionWidth: CGFloat { Tokens.Size.swipeAction }
    private var revealed: CGFloat { max(-offset, 0) }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(isDeleting ? 0 : 1)
            // While open, a tap on the card closes it rather than opening it.
            .overlay(alignment: .leading) {
                if isOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: max(width - revealed, 0))
                        .onTapGesture { close() }
                }
            }
            .background(alignment: .trailing) { if !isDeleting { deleteButton } }
            .gesture(HorizontalPan(
                canBegin: { velocity in velocity.x < 0 || isOpen },
                onChange: { translation in
                    let start = isOpen ? -actionWidth : 0
                    // Follows the finger to the button's width, then only gives a little more.
                    let raw = min(0, start + translation)
                    offset = raw < -actionWidth ? -actionWidth - (-raw - actionWidth) * 0.15 : raw
                },
                onEnd: { velocity in finish(velocity: velocity) }
            ))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .accessibilityAction(named: "Delete") { deleteNow() }
    }

    private var deleteButton: some View {
        Button {
            deleteNow()
        } label: {
            Label("Delete", systemImage: "trash")
                .labelStyle(.titleAndIcon)
                .textStyle(Typography.pill)
                .foregroundStyle(Tokens.Ink.onBrand)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).fill(Tokens.System.error))
        }
        .buttonStyle(.plain)
        .frame(width: max(revealed - Tokens.Spacing.tight, 0))
        .opacity(revealed > Tokens.Spacing.tight ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func finish(velocity: CGPoint) {
        if revealed > actionWidth / 2 || (velocity.x < -300 && revealed > 0) {
            withAnimation(.snappy(duration: 0.25)) { offset = -actionWidth }
            isOpen = true
        } else {
            close()
        }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.25)) { offset = 0 }
        isOpen = false
    }

    /// The card simply fades away where it is (user, 2026-10-15: no slide left then right), and
    /// the list closes the gap. If deleting fails it comes back, closed.
    private func deleteNow() {
        isOpen = false
        withAnimation(.easeOut(duration: 0.15)) { isDeleting = true }
        Task {
            if await onDelete() { return }
            offset = 0
            withAnimation(.easeOut(duration: 0.2)) { isDeleting = false }
        }
    }
}

/// A pan that starts only when the finger moves more sideways than up or down, so it never
/// takes a scroll; `canBegin` gets the starting velocity.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    let canBegin: (CGPoint) -> Bool
    let onChange: (CGFloat) -> Void
    let onEnd: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(canBegin: canBegin)
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.canBegin = canBegin
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .changed:
            onChange(recognizer.translation(in: recognizer.view).x)
        case .ended, .cancelled, .failed:
            onEnd(recognizer.velocity(in: recognizer.view))
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var canBegin: (CGPoint) -> Bool

        init(canBegin: @escaping (CGPoint) -> Bool) {
            self.canBegin = canBegin
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2 && canBegin(velocity)
        }
    }
}

extension View {
    /// Swipe right to left to delete, as iOS does for an alarm (decision 60).
    func swipeToDelete(_ onDelete: @escaping () async -> Bool) -> some View {
        modifier(SwipeToDelete(onDelete: onDelete))
    }
}
