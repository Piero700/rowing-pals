//
//  TestsView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 6A — distance picker. Real PBs come from `test_results` in task 14;
/// this is the static grid with mock values. Only the 2k tile is interactive
/// for this pass — the rest are static placeholders.
struct TestsView: View {
    private struct DistanceTile {
        let label: String
        let pb: String
    }

    private let tiles = [
        DistanceTile(label: "500m", pb: "1:28.4"),
        DistanceTile(label: "1k", pb: "3:02.6"),
        DistanceTile(label: "2k", pb: "6:18.9"),
        DistanceTile(label: "5k", pb: "17:12.4"),
        DistanceTile(label: "6k", pb: "20:54.8"),
        DistanceTile(label: "10k", pb: "35:48.0"),
        DistanceTile(label: "4min", pb: "—"),
        DistanceTile(label: "30min", pb: "8,410m"),
        DistanceTile(label: "60min", pb: "16,220m")
    ]

    @State private var showTwoKBoard = false

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tests")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("Your bests, and where they rank.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .padding(.top, 56)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(tiles, id: \.label) { tile in
                        distanceTile(tile)
                            .onTapGesture {
                                if tile.label == "2k" { showTwoKBoard = true }
                            }
                    }
                }

                Text("RECENT IN YOUR CLUB")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)

                VStack(spacing: 8) {
                    recentRow(name: "Marcus Reilly", detail: "2k · 2 days ago", time: "6:31.5")
                    recentRow(name: "Ollie Grant", detail: "5k · 4 days ago", time: "19:02.7")
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 16)
        }
        .background(Tokens.Base.ground)
        .fullScreenCover(isPresented: $showTwoKBoard) {
            TestBoardView()
        }
    }

    private func distanceTile(_ tile: DistanceTile) -> some View {
        VStack(spacing: 6) {
            Text(tile.label)
                .font(.system(size: 21, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(tile.pb)
                .font(.system(size: 13.5, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 106)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.08))
        }
    }

    private func recentRow(name: String, detail: String, time: String) -> some View {
        HStack(spacing: 12) {
            AvatarPlaceholder(diameter: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(detail)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text(time)
                .font(.system(size: 16, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.05))
        }
    }
}

#Preview {
    TestsView()
}
