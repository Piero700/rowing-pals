//
//  TestLeaderboardView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 6B — one standard distance's leaderboard. Male/Female on top,
/// All/Novice/Senior beneath, filtering on the snapshot columns baked into
/// each `test_results` row — never the rower's live profile (task 11's
/// whole point). Works for any of the nine standard tests, not just 2k.
struct TestLeaderboardView: View {
    @State private var viewModel: TestLeaderboardViewModel
    @Environment(\.dismiss) private var dismiss

    init(test: StandardTest) {
        _viewModel = State(initialValue: TestLeaderboardViewModel(test: test))
    }

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
                    Text(viewModel.test.label)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                }
                .padding(.top, 52)

                PillSegmentedControl(options: ["Male", "Female"], selection: genderSelection)
                PillSegmentedControl(options: TestLeaderboardViewModel.CategoryFilter.allCases.map(\.label), selection: categorySelection)

                Text(scopeDescription)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)

                if viewModel.rows.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.rows) { row in
                            rowView(row)
                        }
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
        .edgeSwipeToDismiss()
        .task { await viewModel.loadInitial() }
        .refreshable { await viewModel.reload() }
    }

    private var genderSelection: Binding<Int> {
        Binding(
            get: { viewModel.gender == .male ? 0 : 1 },
            set: { viewModel.gender = $0 == 0 ? .male : .female }
        )
    }

    private var categorySelection: Binding<Int> {
        Binding(
            get: { viewModel.category.rawValue },
            set: { viewModel.category = TestLeaderboardViewModel.CategoryFilter(rawValue: $0) ?? .all }
        )
    }

    private var scopeDescription: String {
        let genderWord = viewModel.gender == .male ? "Men" : "Women"
        return switch viewModel.category {
        case .all: "\(genderWord) overall · best result per rower"
        case .novice: "Novice \(genderWord.lowercased()) · best result per rower"
        case .senior: "Senior \(genderWord.lowercased()) · best result per rower"
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                Text("Couldn't load this leaderboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(errorMessage)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Nobody's set this test yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Post a \(viewModel.test.label) main piece to be the first.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    private func rowView(_ row: TestLeaderboardViewModel.Row) -> some View {
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
                    if viewModel.category == .all {
                        Text(row.category.rawValue.uppercased())
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
                    if row.isRecentPB {
                        Text("PB")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Tokens.Base.dark)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Tokens.Accent.pb)
                            }
                    }
                }
                Text("\(row.club ?? "No club") · \(row.dateLabel)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(row.primaryValue)
                    .font(.system(size: 18, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("\(row.splitValue) /500m")
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
    TestLeaderboardView(test: StandardTest.all[2])
}
