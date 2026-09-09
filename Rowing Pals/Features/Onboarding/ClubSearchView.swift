//
//  ClubSearchView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 1 of onboarding — find a club, then set up name/gender/category.
/// Static mock UI; real club search and profile writes arrive with task 06.
struct ClubSearchView: View {
    private struct MockClub {
        let name: String
        let location: String
        let memberCount: Int
    }

    private static let mockClubs = [
        MockClub(name: "UEA Boat Club", location: "Norwich", memberCount: 48),
        MockClub(name: "UEA Novice Squad", location: "Norwich", memberCount: 31),
        MockClub(name: "Norwich Rowing Club", location: "Norwich", memberCount: 86)
    ]

    @State private var searchText = "UEA"
    @State private var categorySelection = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find your club")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("Your feed, leaderboards and squad live here.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Tokens.Ink.secondary)
                    TextField("Search clubs", text: $searchText)
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.primary)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .glassSurface(cornerRadius: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Tokens.Accent.signal.opacity(0.55), lineWidth: 1.5)
                }

                VStack(spacing: 10) {
                    ForEach(Self.mockClubs, id: \.name) { club in
                        HStack(spacing: 14) {
                            AvatarPlaceholder(diameter: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(club.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Tokens.Ink.primary)
                                Text("\(club.memberCount) members · \(club.location)")
                                    .textStyle(Typography.bodySecondary)
                                    .tabularNumerals()
                                    .foregroundStyle(Tokens.Ink.secondary)
                            }
                            Spacer()
                            Text("Join")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Tokens.Accent.signal)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background {
                                    Capsule().fill(Tokens.Accent.signal.opacity(0.16))
                                }
                        }
                        .padding(14)
                        .glassSurface(cornerRadius: 20)
                    }

                    HStack(spacing: 10) {
                        Text("Create a club")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .glassSurface(cornerRadius: 18)
                        Text("Invite code")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .glassSurface(cornerRadius: 18)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Divider().opacity(0.3)
                    Text("NEXT · ABOUT YOU")
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary)

                    HStack(spacing: 10) {
                        Text("Name")
                            .textStyle(Typography.body)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .glassSurface(cornerRadius: 16)
                        Text("Gender")
                            .textStyle(Typography.body)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 14)
                            .frame(width: 110, height: 44)
                            .glassSurface(cornerRadius: 16)
                    }

                    PillSegmentedControl(options: ["Novice", "Senior"], selection: $categorySelection)

                    Text("Novice means you're in your first season. You can change this any time.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            .padding(24)
        }
        .background(Tokens.Base.ground)
    }
}

#Preview {
    ClubSearchView()
}
