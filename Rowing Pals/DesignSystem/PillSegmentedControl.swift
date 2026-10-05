//
//  PillSegmentedControl.swift
//  Rowing Pals
//

import SwiftUI

/// The v3 segmented control (docs/design/rowing-pals-v3-spec.md §Layout — Segmented control):
/// a glass capsule, 4 pt padding, equal segments with no gap, each at least 44 pt tall, and a
/// glass thumb that slides to the selected segment with a slight overshoot. Every segment is a
/// real button whose whole capsule is tappable. Used for Following/Club, Volume/Test results,
/// Overview/PBs/Posts and similar small option sets.
struct PillSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int
    /// v3's settings-row variant: 38 pt segments, 3 pt padding, 13 pt labels.
    var compact = false

    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                segment(index)
            }
        }
        .padding(compact ? 3 : 4)
        .glassSurface(in: Capsule())
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
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Tokens.Ink.primary : Tokens.Ink.secondary)
                // A compact segment draws 36 pt but still takes taps across 44 pt.
                .frame(maxWidth: .infinity, minHeight: compact ? Tokens.Size.compactSegment : Tokens.Size.minTap)
                .background {
                    if isSelected {
                        Color.clear
                            .glassSurface(in: Capsule(), isSelected: true, usesNativeGlass: false)
                            .matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule().inset(by: compact ? -4 : 0))
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
