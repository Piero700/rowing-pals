//
//  PostActionsBubble.swift
//  Rowing Pals
//

import SwiftUI

/// A small glass bubble with your own post's actions, sized to its buttons and pointing at what
/// opened it (user, 2026-10-15): "Make private" or "Make visible" (decision 106), then a red
/// "Delete post". iOS's own menus are drawn at a fixed minimum width, which left short items with a
/// wide empty space on their right.
private struct PostActionsBubble: ViewModifier {
    @Binding var isPresented: Bool
    let isPrivate: Bool
    let onTogglePrivate: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    isPresented = false
                    onTogglePrivate()
                } label: {
                    Label(isPrivate ? "Make visible" : "Make private", icon: isPrivate ? .eye : .eyeOff)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.horizontal, Tokens.Spacing.card)
                        .frame(maxWidth: .infinity, minHeight: Tokens.Size.minTap, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                Rectangle()
                    .fill(Tokens.Surface.line)
                    .frame(height: Tokens.Grouped.hairline)
                Button(role: .destructive) {
                    isPresented = false
                    onDelete()
                } label: {
                    Label("Delete post", icon: .trash)
                        .textStyle(Typography.cardTitle)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, Tokens.Spacing.card)
                        .frame(maxWidth: .infinity, minHeight: Tokens.Size.minTap, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
            }
            .fixedSize()
            .padding(Tokens.Spacing.tight)
            .presentationCompactAdaptation(.popover)
        }
    }
}

extension View {
    /// Shows your own post's actions — make it private or visible, delete it — while `isPresented`.
    func postActionsBubble(
        isPresented: Binding<Bool>, isPrivate: Bool,
        onTogglePrivate: @escaping () -> Void, onDelete: @escaping () -> Void
    ) -> some View {
        modifier(PostActionsBubble(isPresented: isPresented, isPrivate: isPrivate,
                                   onTogglePrivate: onTogglePrivate, onDelete: onDelete))
    }
}
