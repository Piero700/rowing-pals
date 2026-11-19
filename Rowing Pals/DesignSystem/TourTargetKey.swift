//
//  TourTargetKey.swift
//  Rowing Pals
//

import SwiftUI

/// Where each tab bar control sits, for the first-run tour (decision 109) to point at.
struct TourTargetKey: PreferenceKey {
    static let defaultValue: [TourStep.Target: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourStep.Target: Anchor<CGRect>], nextValue: () -> [TourStep.Target: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this control as something the tour can point at.
    func tourTarget(_ target: TourStep.Target) -> some View {
        anchorPreference(key: TourTargetKey.self, value: .bounds) { [target: $0] }
    }
}
