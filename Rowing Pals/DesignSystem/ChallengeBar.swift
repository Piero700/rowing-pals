//
//  ChallengeBar.swift
//  Rowing Pals
//

import SwiftUI

/// A challenge's progress bar (decision 91): how much of a target or a club total is done, or a
/// squad's metres per rower against the leader's. Yours in brand blue, a finished target in the
/// success green, everyone else's in ink.
struct ChallengeBar: View {
    /// 0 … 1.
    let fraction: Double
    var isMine = false
    var isDone = false
    var height: CGFloat = Tokens.Size.targetBar

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Tokens.Surface.raised)
                Capsule()
                    .fill(isDone ? Tokens.Accent.success : (isMine ? Tokens.Accent.brand : Tokens.Ink.secondary))
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
