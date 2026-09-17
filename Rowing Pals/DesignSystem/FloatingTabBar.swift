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
/// scroll-linked behaviour `.tabBarMinimizeBehavior` used to give for free.
///
/// Real-device feedback (2026-09-17) on the first cut: too large and sitting
/// too high, and the two shapes shouldn't behave the same way on scroll —
/// "the 3 buttons should disappear then the plus should get slightly
/// smaller as you scroll down but it should stay on the page for easy
/// access." So the pill fully hides (and stops accepting touches — a
/// SwiftUI view scaled/faded to invisible still blocks touches at its
/// *layout* frame unless hit-testing is explicitly turned off, which is
/// exactly what made scrolling feel unresponsive on the first cut) while
/// the Log button only shrinks a little and stays tappable throughout.
struct FloatingTabBar<Tab: Hashable>: View {
    struct Item {
        let tab: Tab
        let label: String
        let systemImage: String
    }

    private static var barHeight: CGFloat { 60 }

    let items: [Item]
    @Binding var selection: Tab
    let onTapLog: () -> Void

    @Environment(FloatingBarVisibility.self) private var visibility

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(items, id: \.tab) { item in
                    tabButton(item)
                }
            }
            .padding(4)
            .frame(height: Self.barHeight)
            .glassSurface(cornerRadius: 999)
            .opacity(visibility.isExpanded ? 1 : 0)
            .scaleEffect(visibility.isExpanded ? 1 : 0.85, anchor: .bottom)
            .allowsHitTesting(visibility.isExpanded)

            Button(action: onTapLog) {
                // The prototype's plus glyph has no circle in it — the
                // circular look comes entirely from the container.
                // `plus.circle.fill` would double up on that.
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Tokens.Accent.brand)
                    .frame(width: Self.barHeight, height: Self.barHeight)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: 999)
            // Stays visible and tappable at all times — this is the app's
            // primary action, never hidden, only a visual cue that
            // scrolling is happening.
            .scaleEffect(visibility.isExpanded ? 1 : 0.86)
        }
        .padding(.horizontal, 12)
        .animation(.easeOut(duration: 0.3), value: visibility.isExpanded)
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = item.tab == selection
        return Button {
            selection = item.tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 19))
                Text(item.label)
                    .font(.system(size: 11, weight: .semibold))
            }
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
