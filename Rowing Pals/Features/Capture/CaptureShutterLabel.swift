//
//  CaptureShutterLabel.swift
//  Rowing Pals
//

import SwiftUI

/// The Log shutter: 76 pt white, with a 6 pt raised ring and a 2 pt white outer edge.
struct CaptureShutterLabel: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 64, height: 64)
            .padding(6)
            .background(Circle().fill(Tokens.Surface.raised))
            .padding(2)
            .background(Circle().fill(Color.white))
            .contentShape(Circle())
    }
}
