//
//  FloatingTabBar.swift
//  Rowing Pals
//

import SwiftUI

/// The redesign's bottom nav (docs/design/rowing-pals-redesign-handoff-v2.md
/// §4): NOT one bar — two separate floating glass shapes side by side, a
/// pill grouping the real tabs and a standalone circular button for Log.
/// Replaces the native `TabView` bar entirely, so `RootView` hand-builds
/// tab switching and this reacts to `FloatingBarVisibility` for the
/// shrink/expand-on-scroll behaviour `.tabBarMinimizeBehavior` used to
/// give for free.
struct FloatingTabBar<Tab: Hashable>: View {
    struct Item {
        let tab: Tab
        let label: String
        let systemImage: String
    }

    let items: [Item]
    @Binding var selection: Tab
    let onTapLog: () -> Void

    @Environment(FloatingBarVisibility.self) private var visibility

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(items, id: \.tab) { item in
                    tabButton(item)
                }
            }
            .padding(5)
            .frame(height: 76)
            .glassSurface(cornerRadius: 999)

            Button(action: onTapLog) {
                // The prototype's plus glyph has no circle in it — the
                // circular look comes entirely from the 76×76 container.
                // `plus.circle.fill` would double up on that.
                Image(systemName: "plus")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: 76, height: 76)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 999)
        }
        .padding(.horizontal, 14)
        .scaleEffect(visibility.isExpanded ? 1 : 0.001, anchor: .bottom)
        .opacity(visibility.isExpanded ? 1 : 0)
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = item.tab == selection
        return Button {
            selection = item.tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 23))
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Tokens.Accent.brand : Tokens.Ink.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background {
                if isSelected {
                    Capsule().fill(Tokens.Accent.brandSoft)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
