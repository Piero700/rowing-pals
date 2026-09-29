//
//  FloatingTabBar.swift
//  Rowing Pals
//

import SwiftUI

/// The v3 bottom navigation (docs/design/rowing-pals-v3-spec.md §Layout — Bottom navigation):
/// a 58 pt glass pill holding Feed / Rankings / Profile (three equal columns, 4 pt padding) and,
/// 4 pt to its right, a separate 58 × 58 glass circle for Log. 16 pt from the screen sides,
/// 6 pt from the bottom. Selected item: the stronger glass thumb (sliding) and brand colour.
///
/// Taps never pass through. Every item and the Log button are hittable across their whole
/// shape, and the pill itself swallows taps that land in its padding. Before this, the items
/// used the `.plain` button style, which only answers taps on drawn pixels — a tap between the
/// icon and the label fell through to the feed card underneath and opened a post.
///
/// Scroll behaviour is unchanged from 2026-09-17 device feedback: scrolling down hides the pill
/// (and stops it taking touches) while the Log button only shrinks and stays tappable.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: Tokens.Size.navGap) {
            pill
                .opacity(visibility.isExpanded ? 1 : 0)
                .scaleEffect(visibility.isExpanded ? 1 : 0.85, anchor: .bottom)
                .allowsHitTesting(visibility.isExpanded)

            logButton
                .scaleEffect(visibility.isExpanded ? 1 : 0.86)
        }
        // While the pill shows, the 4 pt gap between it and Log absorbs taps too, so nothing
        // along the bar reaches the post underneath. Hidden, the pill's area lets taps through.
        .background {
            if visibility.isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {}
            }
        }
        .padding(.horizontal, Tokens.Size.navSideInset)
        .padding(.bottom, Tokens.Size.navBottomInset)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: visibility.isExpanded)
    }

    private var pill: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                tabButton(item)
            }
        }
        .padding(4)
        .frame(height: Tokens.Size.navHeight)
        .glassSurface(in: Capsule())
        // Taps on the pill's own padding stop here instead of reaching the screen below.
        .contentShape(Capsule())
        .onTapGesture {}
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = item.tab == selection
        return Button {
            guard item.tab != selection else { return }
            if reduceMotion {
                selection = item.tab
            } else {
                withAnimation(Tokens.Motion.thumb) { selection = item.tab }
            }
        } label: {
            VStack(spacing: 2) {
                // v3 icons sit in a 20 × 20 box drawn with a thin 1.9 stroke; SF Symbols at
                // 17 pt regular fill that box at the same visual weight.
                Image(systemName: item.systemImage)
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 20, height: 20)
                Text(item.label)
                    .textStyle(Typography.navLabel)
            }
            .foregroundStyle(isSelected ? Tokens.Accent.brand : Tokens.Ink.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    Color.clear
                        .glassSurface(in: Capsule(), isSelected: true, usesNativeGlass: false)
                        .matchedGeometryEffect(id: "thumb", in: thumb)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// Icon only (plus, 24 pt, brand) — the circle comes from the glass container.
    private var logButton: some View {
        Button(action: onTapLog) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Tokens.Accent.brand)
                .frame(width: Tokens.Size.navHeight, height: Tokens.Size.navHeight)
                .glassSurface(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel("Log workout")
    }
}
