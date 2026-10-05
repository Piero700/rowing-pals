//
//  TargetBar.swift
//  Rowing Pals
//

import SwiftUI

/// The 6 pt bar under a rower's week: how much of the weekly target they've done, red while
/// they're behind the pro-rata share (decision 43).
struct TargetBar: View {
    let metres: Int
    let target: Int
    let isBehind: Bool

    var body: some View {
        GeometryReader { geometry in
            let fraction = target > 0 ? min(1, Double(metres) / Double(target)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.Surface.raised)
                Capsule()
                    .fill(isBehind ? Tokens.System.error : Tokens.Ink.primary)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: Tokens.Size.targetBar)
        .accessibilityHidden(true)
    }
}
