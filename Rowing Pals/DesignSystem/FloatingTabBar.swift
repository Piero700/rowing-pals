//
//  FloatingTabBar.swift
//  Rowing Pals
//

import SwiftUI

/// The app's bottom nav. Originally built as the redesign prototype's own
/// two-separate-glass-capsules bottom nav (docs/design/rowing-pals-redesign-handoff-v2.md
/// §4) — after living with that on a real device, the user asked for
/// Instagram's bar instead (screen recording supplied 2026-09-18): **one**
/// unified floating pill holding every icon together, icon-only (no text
/// labels), sitting close to the bottom edge. This replaces the split
/// version entirely; Log is just the bar's third icon now, not a separate
/// circular button.
///
/// Still not a native `TabView` bar — `RootView` hand-builds tab
/// switching and this reacts to `FloatingBarVisibility` for the
/// scroll-linked shrink/expand behaviour `.tabBarMinimizeBehavior` used
/// to give for free, since Log needs to open a sheet rather than actually
/// becoming a selected tab (same "Post sits outside tab selection"
/// pattern this app has always had).
struct FloatingTabBar<Tab: Hashable>: View {
    struct Item {
        let tab: Tab
        let systemImage: String
        /// nil for the Log item — it calls `onTapLog` instead of changing
        /// `selection`.
        let isLog: Bool

        init(tab: Tab, systemImage: String, isLog: Bool = false) {
            self.tab = tab
            self.systemImage = systemImage
            self.isLog = isLog
        }
    }

    private static var barHeight: CGFloat { 54 }

    let items: [Item]
    @Binding var selection: Tab
    let onTapLog: () -> Void

    @Environment(FloatingBarVisibility.self) private var visibility

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                button(item)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: Self.barHeight)
        .glassSurface(cornerRadius: 999)
        .padding(.horizontal, 16)
        .scaleEffect(visibility.isExpanded ? 1 : 0.001, anchor: .bottom)
        .opacity(visibility.isExpanded ? 1 : 0)
        .allowsHitTesting(visibility.isExpanded)
        .animation(.easeOut(duration: 0.3), value: visibility.isExpanded)
    }

    private func button(_ item: Item) -> some View {
        let isSelected = !item.isLog && item.tab == selection
        return Button {
            if item.isLog {
                onTapLog()
            } else {
                selection = item.tab
            }
        } label: {
            Image(systemName: item.systemImage)
                .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Tokens.Accent.brand : Tokens.Ink.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: Self.barHeight - 8)
                .background {
                    if isSelected {
                        Capsule().fill(Tokens.Accent.brandSoft)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
