//
//  TestBoardView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 6B — 2k leaderboard, filtered by gender and category snapshots
/// (never the live profile — see CLAUDE.md and task 11). Real filtering
/// arrives with task 14; this is the static board with mock rows.
struct TestBoardView: View {
    private struct Row: Identifiable {
        let id = UUID()
        let rank: Int
        let name: String
        let club: String
        let time: String
        let split: String
        let category: String
        let date: String
    }

    private let rows = [
        Row(rank: 1, name: "Tom Ashworth", club: "Newcastle University BC", time: "6:04.2", split: "1:31.0", category: "SENIOR", date: "12 Feb"),
        Row(rank: 2, name: "Jack Fenwick", club: "Durham University BC", time: "6:11.7", split: "1:32.9", category: "SENIOR", date: "3 Feb"),
        Row(rank: 3, name: "Piero Ciobanu", club: "UEA Boat Club", time: "6:18.9", split: "1:34.7", category: "SENIOR", date: "28 Jan"),
        Row(rank: 4, name: "Marcus Reilly", club: "UEA Boat Club", time: "6:31.5", split: "1:37.9", category: "SENIOR", date: "2 days ago"),
        Row(rank: 5, name: "Sam Okonkwo", club: "UEA Boat Club", time: "6:52.4", split: "1:43.1", category: "NOVICE", date: "19 Jan"),
        Row(rank: 6, name: "Ollie Grant", club: "UEA Boat Club", time: "7:05.2", split: "1:46.3", category: "NOVICE", date: "9 Jan")
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var genderSelection = 0
    @State private var categorySelection = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    Text("2k")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                }
                .padding(.top, 52)

                PillSegmentedControl(options: ["Male", "Female"], selection: $genderSelection)
                PillSegmentedControl(options: ["All", "Novice", "Senior"], selection: $categorySelection)

                Text("Men overall · best result per rower")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)

                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        rowView(row)
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
    }

    private func rowView(_ row: Row) -> some View {
        let isPodium = row.rank <= 3
        return HStack(spacing: 11) {
            Text("\(row.rank)")
                .font(.system(size: 19, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(isPodium ? Tokens.Accent.pb : Tokens.Ink.secondary)
                .frame(width: 24)
            AvatarPlaceholder(diameter: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(row.category)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Tokens.Ink.primary.opacity(0.1))
                        }
                }
                Text("\(row.club) · \(row.date)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(row.time)
                    .font(.system(size: 18, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("\(row.split) /500m")
                    .font(.system(size: 12))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isPodium ? Tokens.Accent.pb.opacity(0.07) : Tokens.Ink.primary.opacity(0.05))
        }
    }
}

#Preview {
    TestBoardView()
}
