//
//  MetresView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 5 — Metres leaderboard. Real aggregation from `daily_totals`
/// arrives with task 13; this is the static layout with mock rows. UK
/// spelling "Metres" per CLAUDE.md's domain vocabulary.
struct MetresView: View {
    struct Row: Identifiable {
        let id = UUID()
        let rank: Int
        let name: String
        let club: String
        let metres: String
        let ergFraction: Double
    }

    static let podium = [
        Row(rank: 1, name: "Tom Ashworth", club: "Newcastle University BC", metres: "128,400", ergFraction: 0.82),
        Row(rank: 2, name: "Jack Fenwick", club: "Durham University BC", metres: "121,900", ergFraction: 0.7),
        Row(rank: 3, name: "Piero Ciobanu", club: "UEA Boat Club", metres: "116,250", ergFraction: 0.78)
    ]

    static let rest = [
        Row(rank: 4, name: "Marcus Reilly", club: "UEA Boat Club", metres: "104,800", ergFraction: 0.64),
        Row(rank: 5, name: "Sam Okonkwo", club: "UEA Boat Club", metres: "41,300", ergFraction: 0.5)
    ]

    @State private var periodSelection = 0
    @State private var genderSelection = 0
    @State private var sourceSelection = 0
    @State private var scopeSelection = 2

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Metres")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, 56)

                PillSegmentedControl(options: ["Week", "Month", "Year"], selection: $periodSelection)

                HStack(spacing: 7) {
                    FilterChip(label: "Male", isSelected: genderSelection == 0)
                        .onTapGesture { genderSelection = 0 }
                    FilterChip(label: "Female", isSelected: genderSelection == 1)
                        .onTapGesture { genderSelection = 1 }
                    Divider().frame(height: 18)
                    FilterChip(label: "All", isSelected: sourceSelection == 0)
                        .onTapGesture { sourceSelection = 0 }
                    FilterChip(label: "Erg", isSelected: sourceSelection == 1)
                        .onTapGesture { sourceSelection = 1 }
                    FilterChip(label: "Water", isSelected: sourceSelection == 2)
                        .onTapGesture { sourceSelection = 2 }
                }

                HStack(spacing: 16) {
                    ForEach(Array(["Following", "My Club", "Global"].enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(.system(size: 13, weight: index == scopeSelection ? .semibold : .regular))
                            .foregroundStyle(index == scopeSelection ? Tokens.Accent.signal : Tokens.Ink.secondary)
                            .onTapGesture { scopeSelection = index }
                    }
                }
                .padding(.top, 2)

                VStack(spacing: 8) {
                    ForEach(Self.podium) { row in
                        podiumRow(row)
                    }
                    ForEach(Self.rest) { row in
                        restRow(row)
                    }
                }
                .padding(.top, 6)

                HStack(spacing: 14) {
                    legendSwatch(opacity: 0.75, label: "Erg")
                    legendSwatch(opacity: 0.28, label: "Water")
                }
                .padding(.top, 2)

                Color.clear.frame(height: 60)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
        .overlay(alignment: .bottom) {
            MetresPinnedRow()
                .padding(.bottom, 20)
        }
    }

    private func podiumRow(_ row: Row) -> some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.system(size: 26, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Accent.pb)
                .frame(width: 26)
            AvatarPlaceholder(diameter: 42)
            rowLabels(row)
            Text(row.metres)
                .font(.system(size: 19, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Accent.pb.opacity(0.07))
        }
    }

    private func restRow(_ row: Row) -> some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(.system(size: 17, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: 26)
            AvatarPlaceholder(diameter: 38)
            rowLabels(row)
            Text(row.metres)
                .font(.system(size: 17, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.05))
        }
    }

    private func rowLabels(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(row.name)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
            Text(row.club)
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle().fill(Tokens.Ink.primary.opacity(0.75))
                        .frame(width: geometry.size.width * row.ergFraction)
                    Rectangle().fill(Tokens.Ink.primary.opacity(0.28))
                }
            }
            .frame(height: 3)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendSwatch(opacity: Double, label: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(Tokens.Ink.primary.opacity(opacity)).frame(width: 14, height: 3)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }
}

/// The pinned "You" row shown above the floating tab bar while on the Metres
/// tab, hosted via `RootView`'s `.tabViewBottomAccessory`.
struct MetresPinnedRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("3")
                .font(.system(size: 20, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Accent.pb)
                .frame(width: 26)
            AvatarPlaceholder(diameter: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("You")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("UEA Boat Club · this week")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("116,250m")
                .font(.system(size: 18, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSurface(cornerRadius: 24)
        .padding(.horizontal, 16)
    }
}

#Preview {
    MetresView()
}
