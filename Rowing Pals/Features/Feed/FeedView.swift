//
//  FeedView.swift
//  Rowing Pals
//

import SwiftUI

struct FeedView: View {
    var body: some View {
        // The scroll view must be the direct descendant of the tab content for
        // TabView's `.tabBarMinimizeBehavior` to see it scroll — a NavigationStack
        // wrapper here breaks that and the bar never minimises.
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("Feed")
                    .textStyle(Typography.displayNumeral)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, 24)

                // Placeholder rows so the tab bar's scroll-to-minimise behaviour
                // has something long enough to scroll.
                ForEach(0..<40) { index in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Tokens.Ink.primary.opacity(0.06))
                        .frame(height: 96)
                        .overlay {
                            Text("Session \(index + 1)")
                                .textStyle(Typography.body)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                        .padding(.horizontal)
                }
            }
        }
        .background(Tokens.Base.ground)
    }
}

#Preview {
    FeedView()
}
