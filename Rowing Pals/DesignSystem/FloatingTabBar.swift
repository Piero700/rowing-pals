//
//  FloatingTabBar.swift
//  Rowing Pals
//

import SwiftUI

/// The v3 bottom navigation (docs/design/rowing-pals-v3-spec.md §Layout — Bottom navigation):
/// a glass pill holding the tabs (equal columns, 4 pt padding) and, beside it, a separate circle
/// for Log (or the coach's +), both `Tokens.Size.tabBarHeight` tall and `navSideInset` from the
/// screen sides. Selected item: the stronger glass thumb (sliding) and brand colour.
///
/// Taps never pass through. Every item and the Log button are hittable across their whole
/// shape, and the pill itself swallows taps that land in its padding. Before this, the items
/// used the `.plain` button style, which only answers taps on drawn pixels — a tap between the
/// icon and the label fell through to the feed card underneath and opened a post.
///
/// Tapping the tab that's already selected reports it through `onReselect` (each tab uses it to
/// scroll to the top and refresh, user 2026-10-04).
///
/// Scroll behaviour is unchanged from 2026-09-17 device feedback: scrolling down hides the pill
/// (and stops it taking touches) while the Log button only shrinks and stays tappable.
struct FloatingTabBar<Tab: Hashable>: View {
    struct Item {
        let tab: Tab
        let label: String
        let icon: RPIcon
    }

    let items: [Item]
    @Binding var selection: Tab
    var onReselect: (Tab) -> Void = { _ in }
    /// False for a coach-only account: no Log button, and the pill sits further in from the
    /// sides (CoachOnlyFeed, decision 34).
    var showsLog = true
    /// What the + does, for VoiceOver: Log workout for a rower, New workout in the coach version.
    var logLabel = "Log workout"
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

            if showsLog {
                logButton
                    .scaleEffect(visibility.isExpanded ? 1 : 0.86)
            }
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
        .padding(.horizontal, showsLog ? Tokens.Size.navSideInset : Tokens.Size.navSideInsetNoLog)
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
        .frame(height: Tokens.Size.tabBarHeight)
        .glassSurface(in: Capsule())
        // Taps on the pill's own padding stop here instead of reaching the screen below.
        .contentShape(Capsule())
        .onTapGesture {}
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = item.tab == selection
        return Button {
            guard item.tab != selection else {
                onReselect(item.tab)
                return
            }
            if reduceMotion {
                selection = item.tab
            } else {
                withAnimation(Tokens.Motion.thumb) { selection = item.tab }
            }
        } label: {
            VStack(spacing: 2) {
                // The canvas's own icon in its 20 × 20 box, 1.9 stroke (decision 80).
                RPIconView(icon: item.icon)
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

    /// v4: a solid brand circle with the plus in the on-brand colour and a soft brand glow
    /// beneath it — the one filled control in the bar, so Log reads as the main action.
    private var logButton: some View {
        Button(action: onTapLog) {
            // 24 with a 2 stroke, as the canvas's Log and + buttons.
            RPIconView(icon: .plus, size: Tokens.Icon.large, weight: 2)
                .foregroundStyle(Tokens.Ink.onBrand)
                .frame(width: Tokens.Size.tabBarHeight, height: Tokens.Size.tabBarHeight)
                .background { Circle().fill(Tokens.Accent.brand) }
                .shadow(color: Tokens.Accent.brand.opacity(0.4), radius: 9, y: 6)
                .contentShape(Circle())
        }
        .buttonStyle(IconPressStyle())
        .accessibilityLabel(logLabel)
    }
}
