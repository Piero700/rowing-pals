//
//  ShareCardFooter.swift
//  Rowing Pals
//

import SwiftUI

/// The foot of the shared picture: the "No iPhone?" line in brand blue, then the wordmark.
struct ShareCardFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            Text(ShareCardRules.footer)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Accent.brand)
                .fixedSize(horizontal: false, vertical: true)
            Text("Rowing Pals")
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
