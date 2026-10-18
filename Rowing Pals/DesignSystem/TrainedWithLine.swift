//
//  TrainedWithLine.swift
//  Rowing Pals
//

import SwiftUI

/// "with Sam, Joe and Ella" on a post (decision 90): first names, each opening that rower's
/// profile; more than four reads "with Sam, Joe, Ella and 3 others", the others in the post.
struct TrainedWithLine: View {
    let tags: [SessionTag]
    let onOpen: (UUID) -> Void
    /// The post page names everyone; the Feed card stops at four.
    var showsEveryone = false

    var body: some View {
        let shown = showsEveryone || tags.count <= 4 ? tags : Array(tags.prefix(3))
        let hidden = tags.count - shown.count
        WrapLayout(spacing: 4) {
            Text("with")
                .foregroundStyle(Tokens.Ink.secondary)
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, tag in
                Button {
                    onOpen(tag.userId)
                } label: {
                    Text(SessionTag.firstName(tag.displayName)).fontWeight(.semibold).foregroundStyle(Tokens.Ink.primary)
                        + Text(separator(after: index, shown: shown.count, hidden: hidden)).foregroundStyle(Tokens.Ink.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tag.displayName). Open profile")
            }
            if hidden > 0 {
                Text("\(hidden) others")
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .textStyle(Typography.meta)
        .accessibilityElement(children: .contain)
    }

    /// ", " between names, " and" before the last one (or before "N others").
    private func separator(after index: Int, shown: Int, hidden: Int) -> String {
        let total = shown + (hidden > 0 ? 1 : 0)
        if index == total - 1 { return "" }
        if index == total - 2 { return " and" }
        return ","
    }
}
