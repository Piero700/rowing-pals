//
//  PillSegmentedControl.swift
//  Rowing Pals
//

import SwiftUI

/// The segmented control: since decision 97 (app-wide, 2026-11-05) a compact glass track with
/// small corners, like iOS's own, 2 pt padding, equal segments with no gap (wider for a long label when they
/// can't all fit an equal share — `SegmentRowLayout`), each at least 44 pt tall, and a
/// glass thumb that slides to the selected segment with a slight overshoot. Every segment is a
/// real button whose whole capsule is tappable. Used for Following/Club, Volume/Test results,
/// Overview/PBs/Posts and similar small option sets.
struct PillSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int
    /// v3's settings-row variant: 38 pt segments, 3 pt padding, 13 pt labels.
    var compact = false
    /// The track's and chosen segment's corners; the Feed's are rounder (decision 101).
    var trackRadius: CGFloat = Tokens.Radius.segmentTrack
    var segmentRadius: CGFloat = Tokens.Radius.segment

    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Equal segments when every label fits; otherwise widths by label (user, 2026-10-18).
        SegmentRowLayout {
            ForEach(options.indices, id: \.self) { index in
                segment(index)
            }
        }
        .padding(2)
        .glassSurface(in: RoundedRectangle(cornerRadius: trackRadius, style: .continuous))
    }

    private func segment(_ index: Int) -> some View {
        let isSelected = index == selection
        return Button {
            guard index != selection else { return }
            if reduceMotion {
                selection = index
            } else {
                withAnimation(Tokens.Motion.thumb) { selection = index }
            }
        } label: {
            Text(options[index])
                .textStyle(Typography.segment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? Tokens.Ink.primary : Tokens.Ink.secondary)
                .padding(.horizontal, Tokens.Spacing.segmentInset)
                // A compact segment draws 36 pt but still takes taps across 44 pt.
                .frame(maxWidth: .infinity, minHeight: compact ? Tokens.Size.compactSegment : Tokens.Size.segment)
                .background {
                    if isSelected {
                        Color.clear
                            .glassSurface(in: RoundedRectangle(cornerRadius: segmentRadius, style: .continuous),
                                          isSelected: true, usesNativeGlass: false)
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Rectangle().inset(by: compact ? -4 : -2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection = 0
    PillSegmentedControl(options: ["Following", "Club"], selection: $selection)
        .padding(16)
        .background(Tokens.Base.ground)
}
