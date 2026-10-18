//
//  DeleteBubble.swift
//  Rowing Pals
//

import SwiftUI

/// A small glass bubble holding one red action ("Delete post"), sized to the button and pointing
/// at what opened it (user, 2026-10-15). iOS's own menus are drawn at a fixed minimum width, which
/// left a single short item with a wide empty space on its right.
private struct DeleteBubble: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.popover(isPresented: $isPresented, arrowEdge: .top) {
            Button(role: .destructive) {
                isPresented = false
                action()
            } label: {
                Label(title, icon: .trash)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.System.error)
                    .padding(.horizontal, Tokens.Spacing.card)
                    .frame(minHeight: Tokens.Size.minTap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconPressStyle())
            .padding(Tokens.Spacing.tight)
            .presentationCompactAdaptation(.popover)
        }
    }
}

extension View {
    /// Shows a bubble with one red action, e.g. "Delete post", while `isPresented`.
    func deleteBubble(isPresented: Binding<Bool>, title: String, action: @escaping () -> Void) -> some View {
        modifier(DeleteBubble(isPresented: isPresented, title: title, action: action))
    }
}
