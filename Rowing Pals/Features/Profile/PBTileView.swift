//
//  PBTileView.swift
//  Rowing Pals
//

import SwiftUI

/// v3 PB tile (Profile, Rower profile, All personal bests): card fill, 1 pt line, radius 24,
/// at least 90 tall — the test, its best in the records colour, a footnote, and a › when
/// there's a history to open. A test with no result says so and does nothing on tap.
struct PBTileView: View {
    let tile: ProfileViewModel.PBTile
    /// Defaults to the short title ("2K", "30 MIN").
    var label: String?
    /// Defaults to "View PB history ›".
    var footnote: String?
    let onOpen: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text(label ?? tile.test.shortTitle)
                .textStyle(Typography.statLabel)
                .fontWeight(.bold)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(tile.displayValue ?? "—")
                .textStyle(Typography.metricValue)
                .tabularNumerals()
                .foregroundStyle(tile.hasResult ? Tokens.Accent.records : Tokens.Ink.secondary)
                .padding(.top, 4)
                .padding(.bottom, 2)
            Text(tile.hasResult ? (footnote ?? "View PB history ›") : "No result yet")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.faint)
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 24)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if tile.hasResult {
                Text("›")
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
        }
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
        .asButton {
            guard tile.hasResult else { return }
            onOpen()
        }
        .accessibilityLabel("\(tile.test.label) personal best, \(tile.displayValue ?? "none")")
    }
}
