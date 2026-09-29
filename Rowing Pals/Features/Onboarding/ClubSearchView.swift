//
//  ClubSearchView.swift
//  Rowing Pals
//

import SwiftUI
import Supabase

/// Onboarding, to v3 §01 (`docs/design/v3/RP Screen.dc.html`), then "About you"
/// (decision 24). Step one — "Set up your crew / Find your club": a club search, club rows
/// (44 pt crest, name, members · place, a check on the chosen one), "I'm not in a club", and a
/// sticky "Continue with <club>". Step two — gender and (in a club) level, which v3 leaves out
/// but the test leaderboards need; the name was given at sign-up. Finishing writes the club (or none),
/// gender, level and `onboarded_at` in one update.
///
/// `.joinLater` is the club step alone, for a rower who onboarded without a club and now
/// picks one from the feed or rankings: it saves the club and closes.
struct ClubSearchView: View {
    enum Mode {
        case onboarding
        case joinLater
    }

    var mode: Mode = .onboarding

    @Environment(AuthState.self) private var authState: AuthState?
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ClubSearchViewModel()
    @State private var isAboutYou = false
    /// True when the rower chose "I'm not in a club".
    @State private var isWithoutClub = false
    @State private var genderSelection = 0
    @State private var categorySelection = 0
    @State private var isSaving = false
    @State private var saveError: String?

    private let genders: [RowerGender] = [.male, .female]
    private let categories: [RowerCategory] = [.novice, .senior]

    var body: some View {
        Group {
            if isAboutYou {
                aboutYouStep
                    .transition(.move(edge: .trailing))
            } else {
                clubStep
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.snappy, value: isAboutYou)
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
    }

    // MARK: - Step one: find your club

    private var clubStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                intro(
                    title: "Find your club",
                    body: mode == .onboarding
                        ? "Your club powers your feed and team rankings. You can also continue without one."
                        : "Your club powers your feed and team rankings."
                )

                Text("Club name")
                    .textStyle(Typography.fieldLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, 6)
                searchField

                clubResults
                    .padding(.top, Tokens.Spacing.loose + 12)

                if mode == .onboarding {
                    Button("I’m not in a club") {
                        viewModel.selectedClub = nil
                        isWithoutClub = true
                        isAboutYou = true
                    }
                    .buttonStyle(.rpText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                } else if let saveError {
                    Text(saveError)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            if mode == .joinLater {
                ScreenHeader(title: "Your club") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyButton(
                viewModel.selectedClub.map { "Continue with \($0.name)" } ?? "Choose a club",
                isEnabled: viewModel.selectedClub != nil
            ) {
                isWithoutClub = false
                if mode == .joinLater {
                    Task { await joinSelectedClub() }
                } else {
                    isAboutYou = true
                }
            }
        }
    }

    /// v3: "SET UP YOUR CREW" in the brand colour, a 33 pt title, then one muted line.
    private func intro(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set up your crew")
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Accent.brand)
            Text(title)
                .textStyle(Typography.onboardingTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.vertical, 8)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .textStyle(Typography.bodyV3)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.bottom, 18)
        }
        .padding(.top, mode == .onboarding ? Tokens.Spacing.loose : 0)
    }

    /// 52 pt, card fill, 1 pt line, radius 24; a 20 pt search icon inset 14.
    private var searchField: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 20, height: 20)
                .foregroundStyle(Tokens.Ink.secondary)
                .accessibilityHidden(true)
            TextField("Search clubs", text: $viewModel.searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityLabel("Club name")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Tokens.Size.input)
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
    }

    @ViewBuilder
    private var clubResults: some View {
        if viewModel.isSearching && viewModel.results.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
        } else if viewModel.results.isEmpty {
            Text("No clubs match that name.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 9) {
                ForEach(viewModel.results) { club in
                    clubRow(club)
                }
            }
        }
    }

    /// v3 club row: at least 76 tall, radius 24; chosen = brand edge on brand-soft with a check.
    private func clubRow(_ club: ClubSearchViewModel.ClubResult) -> some View {
        let isSelected = viewModel.selectedClub?.id == club.id
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack(spacing: 11) {
            Text(club.crest)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Tokens.Accent.brand)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: Tokens.Radius.crest, style: .continuous).fill(Tokens.Surface.raised))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(clubMeta(club))
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                if isSelected {
                    Circle().fill(Tokens.Accent.brand)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Tokens.Ink.onBrand)
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(10)
        .frame(minHeight: 76)
        .background(shape.fill(isSelected ? Tokens.Accent.brandSoft : Tokens.Surface.card))
        .overlay { shape.strokeBorder(isSelected ? Tokens.Accent.brand : Tokens.Surface.line, lineWidth: 1) }
        .asButton { viewModel.selectedClub = club }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "48 members · Norwich". v3's join policy ("Open membership") comes with Clubs (phase G).
    private func clubMeta(_ club: ClubSearchViewModel.ClubResult) -> String {
        let members = "\(club.memberCount) member\(club.memberCount == 1 ? "" : "s")"
        guard let location = club.location, !location.isEmpty else { return members }
        return "\(members) · \(location)"
    }

    // MARK: - Step two: about you

    private var aboutYouStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Back to clubs") {
                    isAboutYou = false
                }
                .padding(.bottom, Tokens.Spacing.loose)

                intro(
                    title: "About you",
                    body: isWithoutClub
                        ? "Tests are ranked by gender, so every rower is compared fairly. You can change this any time in Settings."
                        : "Tests are ranked by gender and level, so every rower is compared fairly. You can change these any time in Settings."
                )

                Text("Gender")
                    .textStyle(Typography.fieldLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, 6)
                PillSegmentedControl(options: ["Male", "Female"], selection: $genderSelection)

                // Novice / senior only matters within a club (user, 2026-09-29).
                if !isWithoutClub {
                    Text("Level")
                        .textStyle(Typography.fieldLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, 18)
                        .padding(.bottom, 6)
                    PillSegmentedControl(options: ["Novice", "Senior"], selection: $categorySelection)
                    Text("Novice means you’re in your first season.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, 8)
                }

                if let saveError {
                    Text(saveError)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.loose)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyButton(
                isWithoutClub ? "Start without a club" : "Start rowing",
                isEnabled: !isSaving
            ) {
                Task { await finishOnboarding() }
            }
        }
    }

    // MARK: - Sticky primary button

    /// v3's bottom bar: the primary button over a fade into the screen ground.
    private func stickyButton(_ title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isSaving {
                    ProgressView().tint(Tokens.Ink.onBrand)
                } else {
                    Text(title)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(!isEnabled || isSaving)
        .padding(.horizontal, Tokens.Spacing.screen)
        .padding(.top, Tokens.Spacing.loose)
        .padding(.bottom, Tokens.Spacing.screen)
        .background {
            LinearGradient(
                stops: [.init(color: Tokens.Base.ground, location: 0.72), .init(color: Tokens.Base.ground.opacity(0), location: 1)],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Saving

    /// The whole of onboarding in one update: club (or none), gender, level, finished.
    private func finishOnboarding() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        struct ProfileUpdate: Encodable {
            let clubId: UUID?
            let gender: RowerGender
            /// Nil without a club: level isn't asked, so the column keeps its default.
            let category: RowerCategory?
            let onboardedAt: Date
            enum CodingKeys: String, CodingKey {
                case clubId = "club_id"
                case gender, category
                case onboardedAt = "onboarded_at"
            }
        }

        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            let update = ProfileUpdate(
                clubId: isWithoutClub ? nil : viewModel.selectedClub?.id,
                gender: genders[genderSelection],
                category: isWithoutClub ? nil : categories[categorySelection],
                onboardedAt: Date()
            )
            try await SupabaseService.shared
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
            await authState?.refreshOnboardingStatus()
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// `.joinLater`: save the chosen club, tell the feed and rankings, close.
    private func joinSelectedClub() async {
        guard let club = viewModel.selectedClub else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        struct ClubUpdate: Encodable {
            let clubId: UUID
            enum CodingKeys: String, CodingKey { case clubId = "club_id" }
        }
        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            try await SupabaseService.shared
                .from("profiles")
                .update(ClubUpdate(clubId: club.id))
                .eq("id", value: userId)
                .execute()
            NotificationCenter.default.post(name: .rowerClubChanged, object: nil)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    ClubSearchView()
        .environment(AuthState())
}
