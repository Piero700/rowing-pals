//
//  ClubSearchView.swift
//  Rowing Pals
//

import SwiftUI
import Supabase

/// Screen 1 of onboarding — find a club, then set up name/gender/category.
/// Writes club_id, display_name, gender and category to the user's
/// `profiles` row in one update once "Continue" is tapped.
struct ClubSearchView: View {
    @Environment(AuthState.self) private var authState
    @State private var viewModel = ClubSearchViewModel()

    @State private var displayName = ""
    @State private var genderSelection = 0
    @State private var categorySelection = 0
    @State private var isSaving = false
    @State private var saveError: String?

    private let genders: [RowerGender] = [.male, .female]
    private let categories: [RowerCategory] = [.novice, .senior]

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
                    TextField("Search clubs", text: $viewModel.searchText)
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.primary)
                        .textInputAutocapitalization(.words)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .glassSurface(cornerRadius: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Tokens.Accent.signal.opacity(0.55), lineWidth: 1.5)
                }

                clubResults

                VStack(alignment: .leading, spacing: 14) {
                    Divider().opacity(0.3)
                    Text("NEXT · ABOUT YOU")
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary)

                    HStack(spacing: 10) {
                        TextField("Name", text: $displayName)
                            .textStyle(Typography.body)
                            .foregroundStyle(Tokens.Ink.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .glassSurface(cornerRadius: 16)

                        Picker("Gender", selection: $genderSelection) {
                            Text("Male").tag(0)
                            Text("Female").tag(1)
                        }
                        .pickerStyle(.menu)
                        .tint(Tokens.Ink.primary)
                        .padding(.horizontal, 14)
                        .frame(width: 110, height: 44)
                        .glassSurface(cornerRadius: 16)
                    }

                    PillSegmentedControl(options: ["Novice", "Senior"], selection: $categorySelection)

                    Text("Novice means you're in your first season. You can change this any time.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }

                if let saveError {
                    Text(saveError)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Accent.live)
                }

                continueButton
            }
            .padding(24)
        }
        .background(Tokens.Base.ground)
    }

    private var clubResults: some View {
        VStack(spacing: 10) {
            if viewModel.isSearching && viewModel.results.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Accent.live)
            } else if viewModel.results.isEmpty {
                Text("No clubs found.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.results) { club in
                    clubRow(club)
                }
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
    }

    private func clubRow(_ club: ClubSearchViewModel.ClubResult) -> some View {
        let isSelected = viewModel.selectedClub?.id == club.id
        return HStack(spacing: 14) {
            AvatarPlaceholder(diameter: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("\(club.memberCount) members · \(club.location ?? "—")")
                    .textStyle(Typography.bodySecondary)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text(isSelected ? "Selected" : "Join")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Tokens.Base.dark : Tokens.Accent.signal)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(isSelected ? Tokens.Accent.signal : Tokens.Accent.signal.opacity(0.16))
                }
        }
        .padding(14)
        .glassSurface(cornerRadius: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedClub = club
        }
    }

    private var continueButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack {
                Spacer()
                if isSaving {
                    ProgressView().tint(Tokens.Base.dark)
                } else {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }
            .foregroundStyle(Tokens.Base.dark)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Tokens.Accent.signal)
            }
        }
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.5)
    }

    private var canContinue: Bool {
        viewModel.selectedClub != nil && !displayName.isEmpty && !isSaving
    }

    private func save() async {
        guard let club = viewModel.selectedClub else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        struct ProfileUpdate: Encodable {
            let clubId: UUID
            let displayName: String
            let gender: RowerGender
            let category: RowerCategory

            enum CodingKeys: String, CodingKey {
                case clubId = "club_id"
                case displayName = "display_name"
                case gender, category
            }
        }

        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            let update = ProfileUpdate(
                clubId: club.id,
                displayName: displayName,
                gender: genders[genderSelection],
                category: categories[categorySelection]
            )
            try await SupabaseService.shared
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
            await authState.refreshOnboardingStatus()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    ClubSearchView()
        .environment(AuthState())
}
