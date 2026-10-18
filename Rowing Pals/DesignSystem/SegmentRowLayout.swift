//
//  SegmentRowLayout.swift
//  Rowing Pals
//

import SwiftUI

/// The segments of a `PillSegmentedControl` in a row (user, 2026-10-18): equal widths when every
/// label fits its share, as the v3 control is drawn; when one doesn't ("Stroke side · Bow side · Both
/// · Cox"), each segment gets the width its label needs plus an equal part of what's left, so a long
/// label keeps its size instead of shrinking beside short ones. Only if even that isn't enough do the
/// widths scale down together (and the labels shrink a little).
struct SegmentRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = self.widths(for: proposal.width, subviews: subviews)
        let height = zip(subviews, widths)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
            .max() ?? 0
        return CGSize(width: widths.reduce(0, +), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = self.widths(for: bounds.width, subviews: subviews)
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width
        }
    }

    /// Each segment's width for the room available.
    private func widths(for available: CGFloat?, subviews: Subviews) -> [CGFloat] {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        guard let available, !ideals.isEmpty else { return ideals }
        let equal = available / CGFloat(ideals.count)
        if ideals.allSatisfy({ $0 <= equal }) {
            return Array(repeating: equal, count: ideals.count)
        }
        let needed = ideals.reduce(0, +)
        if needed <= available {
            let extra = (available - needed) / CGFloat(ideals.count)
            return ideals.map { $0 + extra }
        }
        return ideals.map { $0 * available / needed }
    }
}
