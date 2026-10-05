//
//  ClubSearchView.swift
//  Rowing Pals
//

import SwiftUI
import Supabase

/// Onboarding, to v3 §01 (`docs/design/v3/RP Screen.dc.html`), then "About you"
/// (decision 24). Step one — "Set up your crew / Find your club": a club search, club rows
/// (44 pt crest, name, members · place, a check on the chosen one), "I'm not in a club", and a
/// sticky "Continue with <club>". Step two — gender and level, asked of everyone, which v3 leaves
/// out but the test leaderboards need; the name was given at sign-up. Finishing writes the club (or none),
/// gender, level and `onboarded_at` in one update.
///
/// `.joinLater` is for a rower who onboarded without a club and now picks one from Your crew,
/// the feed or rankings: the club step alone — choosing joins (or asks to join) at once.
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
    /// "Have an invite code?" (decision 25).
    @State private var isEnteringCode = false
    @State private var inviteCode = ""
    /// Set once a code has put the rower in a club, so finishing doesn't join again.
    @State private var joinedByCodeName: String?
    /// Joining later: the rower's join request, waiting or declined (decision 26).
    @State private var myRequest: ClubService.JoinRequest?
    @Environment(\.closeRoute) private var closeRoute
    @Environment(\.scenePhase) private var scenePhase
    /// Onboarding's back button: the account exists by now, so going back means signing out.
    @State private var isConfirmingSignOut = false
    /// "I'm a coach" at About you: no gender or level, no Log button (decision 34).
    @State private var isCoachOnly = false
    /// "<Club> has coaches", shown before joining a club that has any (decision 34).
    @State private var coachNotice: CoachNotice?

    private struct CoachNotice: Identifiable {
        let id = UUID()
        let clubName: String
        let coaches: [CoachJoinNotice.Coach]
        let actionTitle: String
        let proceed: () -> Void
    }

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
        .sheet(item: $coachNotice) { notice in
            CoachJoinNotice(
                clubName: notice.clubName,
                coaches: notice.coaches,
                actionTitle: notice.actionTitle,
                onContinue: {
                    coachNotice = nil
                    notice.proceed()
                },
                onCancel: { coachNotice = nil }
            )
        }
        // Pushed from Your crew, the system bar would add a second back button over our own.
        .toolbar(.hidden, for: .navigationBar)
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

                if mode == .joinLater, let myRequest {
                    requestStatus(myRequest)
                        .padding(.bottom, 16)
                }

                Text("Club name")
                    .textStyle(Typography.fieldLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, 6)
                searchField

                clubResults
                    .padding(.top, Tokens.Spacing.loose + 12)

                Button("Have an invite code?") { isEnteringCode = true }
                    .buttonStyle(.rpText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                if mode == .onboarding {
                    Button("I’m not in a club") {
                        viewModel.selectedClub = nil
                        isWithoutClub = true
                        isAboutYou = true
                    }
                    .buttonStyle(.rpText)
                    .frame(maxWidth: .infinity)
                }
                if let saveError {
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
            } else {
                HStack {
                    GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Back to sign in") {
                        isConfirmingSignOut = true
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, Tokens.Spacing.headerHorizontal)
                .padding(.bottom, 6)
                .background(Tokens.Base.ground)
            }
        }
        .alert("Back to sign in?", isPresented: $isConfirmingSignOut) {
            Button("Sign out") {
                Task { try? await SupabaseService.shared.auth.signOut() }
            }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("You'll be signed out. Your account is kept, so sign in again any time to finish setting up.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyButton(clubButtonTitle, isEnabled: canContinueWithClub) {
                guard let club = viewModel.selectedClub else { return }
                let title = clubButtonTitle
                Task {
                    await afterCoachNotice(clubId: club.id, clubName: club.name, actionTitle: title) {
                        isWithoutClub = false
                        joinedByCodeName = nil
                        if mode == .joinLater {
                            // Level and gender were set at sign-up (user, 2026-10-04): join straight away.
                            Task { await joinSelectedClub() }
                        } else {
                            isAboutYou = true
                        }
                    }
                }
            }
        }
        .alert("Have an invite code?", isPresented: $isEnteringCode) {
            TextField("Invite code", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Join") { Task { await joinWithCode() } }
            Button("Cancel", role: .cancel) { inviteCode = "" }
        } message: {
            Text("Enter the code a club admin shared with you.")
        }
        .task { await refreshMembership() }
        .task {
            guard mode == .joinLater else { return }
            for await _ in ClubLiveUpdates.changes() { await refreshMembership() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshMembership() } }
        }
    }

    /// The chosen club is the one already asked, still waiting.
    private var isAwaitingChosenClub: Bool {
        guard let myRequest, let club = viewModel.selectedClub else { return false }
        return myRequest.club.id == club.id && !myRequest.isDeclined
    }

    private var canContinueWithClub: Bool {
        guard let club = viewModel.selectedClub else { return false }
        return club.joinPolicy != .invite && !isAwaitingChosenClub
    }

    /// v3's sticky label, honest about what happens next for each kind of club: "Requested"
    /// (greyed) while a request waits, "Request again" after a decline (decision 26).
    private var clubButtonTitle: String {
        guard let club = viewModel.selectedClub else { return "Choose a club" }
        if let myRequest, myRequest.club.id == club.id {
            return myRequest.isDeclined ? "Request again" : "Requested"
        }
        switch club.joinPolicy {
        case .open: return mode == .joinLater ? "Join \(club.name)" : "Continue with \(club.name)"
        case .approval: return "Request to join \(club.name)"
        case .invite: return "Invitation only — use a code"
        }
    }

    /// Runs `proceed` at once for a club without coaches; for one with coaches, first shows
    /// "<Club> has coaches" and runs it only if the rower carries on (decision 34). If the
    /// coaches can't be read, nothing is joined: nobody joins without being told.
    private func afterCoachNotice(clubId: UUID, clubName: String, actionTitle: String, proceed: @escaping () -> Void) async {
        saveError = nil
        do {
            let coaches = try await ClubService.coaches(of: clubId)
            guard !coaches.isEmpty else {
                proceed()
                return
            }
            coachNotice = CoachNotice(
                clubName: clubName,
                coaches: coaches.map { CoachJoinNotice.Coach(id: $0.id, name: $0.displayName, detail: $0.coachLine) },
                actionTitle: actionTitle,
                proceed: proceed
            )
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// "Have an invite code?": finds the club, says if it has coaches, then joins straight
    /// away. Joining later, that's it; at onboarding the rower goes on to About you.
    private func joinWithCode() async {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        inviteCode = ""
        guard !code.isEmpty else { return }
        saveError = nil
        do {
            let clubId = try await ClubService.club(forCode: code)
            let row: NameRow? = try? await SupabaseService.shared
                .from("clubs").select("name").eq("id", value: clubId).single()
                .execute().value
            let name = row?.name ?? "this club"
            await afterCoachNotice(clubId: clubId, clubName: name, actionTitle: "Join \(name)") {
                Task { await joinWithCode(code) }
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func joinWithCode(_ code: String) async {
        saveError = nil
        do {
            let clubId = try await ClubService.join(code: code)
            let row: NameRow? = try? await SupabaseService.shared
                .from("clubs").select("name").eq("id", value: clubId).single()
                .execute().value
            joinedByCodeName = row?.name ?? "your club"
            isWithoutClub = false
            if mode == .joinLater {
                dismiss()
            } else {
                isAboutYou = true
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private struct NameRow: Decodable { let name: String }

    /// v3: "SET UP YOUR CREW" in the brand colour, a 33 pt title, then one muted line.
    private func intro(title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set up your crew")
                .textStyle(Typography.overline)
                .foregroundStyle(Tokens.Accent.brand)
            Text(title)
                .textStyle(Typography.onboardingTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.vertical, 8)
                .accessibilityAddTraits(.isHeader)
            if let body {
                Text(body)
                    .textStyle(Typography.bodyV3)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, 16)
            } else {
                Spacer().frame(height: Tokens.Spacing.tight)
            }
        }
    }

    /// 52 pt, card fill, 1 pt line, radius 24; a 20 pt search icon inset 14.
    private var searchField: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack(spacing: 8) {
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
            VStack(spacing: 8) {
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
        return HStack(spacing: 12) {
            Text(club.crest)
                .font(.system(size: 12, weight: .bold))
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
                        .font(.system(size: 11, weight: .bold))
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

    /// v3: "48 members · Norwich · Open membership".
    private func clubMeta(_ club: ClubSearchViewModel.ClubResult) -> String {
        var parts = ["\(club.memberCount) member\(club.memberCount == 1 ? "" : "s")"]
        if let location = club.location, !location.isEmpty { parts.append(location) }
        parts.append(club.joinPolicy.tag)
        return parts.joined(separator: " · ")
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
                    // CoachOnboarding has no line here; the note card below says it for a coach.
                    body: isCoachOnly
                        ? nil
                        : "Tests are ranked by gender and level, so every rower is compared fairly. You can change these any time in Settings."
                )

                // CoachOnboarding (decision 34): rowing, or coaching only.
                Text("How will you use Rowing Pals?")
                    .textStyle(Typography.sectionTitle)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, Tokens.Spacing.tight)
                accountTypeCard(
                    title: "I row",
                    detail: "Log sessions and appear on leaderboards.",
                    isSelected: !isCoachOnly
                ) { isCoachOnly = false }
                accountTypeCard(
                    title: "I’m a coach",
                    detail: "Coach a club. You won’t log sessions or appear on any leaderboard.",
                    isSelected: isCoachOnly
                ) { isCoachOnly = true }
                    .padding(.top, Tokens.Spacing.tight)

                if isCoachOnly {
                    coachOnlyNote
                        .padding(.top, Tokens.Spacing.group)
                } else {
                    // Everyone who rows gives both at sign-up, club or not, so joining a club
                    // later never needs to ask (user, 2026-10-04).
                    Text("Gender")
                        .textStyle(Typography.fieldLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, Tokens.Spacing.group)
                        .padding(.bottom, 6)
                    PillSegmentedControl(options: ["Male", "Female"], selection: $genderSelection)

                    Text("Level")
                        .textStyle(Typography.fieldLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, 16)
                        .padding(.bottom, 6)
                    PillSegmentedControl(options: ["Novice", "Senior"], selection: $categorySelection)
                    Text("Novice means you’re in your first season.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, 8)
                }

                Text("You can change this later in Edit profile.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.loose)

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
            stickyButton(isCoachOnly ? "Start" : isWithoutClub ? "Start without a club" : "Start rowing", isEnabled: !isSaving) {
                Task { await finishOnboarding() }
            }
        }
    }

    /// One account-type choice: a card with a brand ring and tick when chosen.
    private func accountTypeCard(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(detail)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Tokens.Accent.brand)
                .frame(width: Tokens.Size.checkmark)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(Tokens.Spacing.card)
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(isSelected ? Tokens.Accent.brand : Tokens.Surface.line, lineWidth: 1.5) }
        .asButton(action: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Coach only: what that means, in place of gender and level.
    private var coachOnlyNote: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        return HStack(alignment: .top, spacing: Tokens.Spacing.loose) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Tokens.Ink.secondary)
                .accessibilityHidden(true)
            Text("No gender or level needed. You won’t have a Log button, and you’ll reach the Coaching area from Your crew once a club makes you a coach.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Tokens.Spacing.card)
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    // MARK: - Sticky primary button

    /// v3's bottom bar: the primary button over a fade into the screen ground.
    private func stickyButton(_ title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(Tokens.Ink.onBrand)
                } else {
                    Text(title)
                    Image(systemName: "chevron.right")
                        .textStyle(Typography.rowTitle)
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

    /// Joins the chosen club through the server's rules (decision 25) — straight in for an
    /// open club, a request for an approval club — unless a code already did; nil when there's
    /// nothing to join. Throws for an invitation-only club, which needs its code.
    private func joinChosenClub() async throws -> ClubService.JoinOutcome? {
        guard !isWithoutClub, joinedByCodeName == nil, let club = viewModel.selectedClub else { return nil }
        let outcome = try await ClubService.join(club.id)
        if outcome == .inviteOnly {
            throw ClubJoinError.inviteOnly(club.name)
        }
        return outcome
    }

    private enum ClubJoinError: LocalizedError {
        case inviteOnly(String)
        var errorDescription: String? {
            switch self {
            case .inviteOnly(let name): "\(name) is invitation only. Ask an admin for the club's code."
            }
        }
    }

    /// Onboarding: join (or ask to join) the club, then save gender, level and "finished".
    /// An approval club's request stays pending; the rower goes on without a club until an
    /// admin lets them in.
    private func finishOnboarding() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        struct ProfileUpdate: Encodable {
            let gender: RowerGender?
            let category: RowerCategory
            let isRower: Bool
            let onboardedAt: Date
            enum CodingKeys: String, CodingKey {
                case gender, category
                case isRower = "is_rower"
                case onboardedAt = "onboarded_at"
            }

            // A coach-only account has no gender: send null rather than leaving the key out.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(gender, forKey: .gender)
                try c.encode(category, forKey: .category)
                try c.encode(isRower, forKey: .isRower)
                try c.encode(onboardedAt, forKey: .onboardedAt)
            }
        }

        do {
            _ = try await joinChosenClub()
            let userId = try await SupabaseService.shared.auth.session.user.id
            let update = ProfileUpdate(
                gender: isCoachOnly ? nil : genders[genderSelection],
                category: categories[categorySelection],
                isRower: !isCoachOnly,
                onboardedAt: Date()
            )
            try await SupabaseService.shared
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
            // The tab bar reads the account type from here (no Log button for a coach).
            ViewerContext.shared.invalidate()
            await authState?.refreshOnboardingStatus()
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// `.joinLater`: join (or ask to join) the chosen club — no level step, as everyone gives
    /// theirs at sign-up. Joining closes straight away (`ClubService` tells the feed, rankings
    /// and profile); a request stays here, waiting.
    private func joinSelectedClub() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            let outcome = try await joinChosenClub()
            if outcome == .requested {
                // Stay on this page: the button now reads "Requested" and the page updates
                // by itself until an admin answers (decision 26).
                await refreshMembership()
            } else {
                dismiss()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Waiting for an answer (decision 26)

    /// Joining later: reads the rower's request. If a waiting request has just been accepted,
    /// the whole club screen closes, back to where they started.
    private func refreshMembership() async {
        guard mode == .joinLater, let membership = try? await ClubService.membership() else { return }
        let wasWaiting = myRequest?.isDeclined == false
        myRequest = membership.request
        if wasWaiting, membership.club != nil {
            NotificationCenter.default.postRowerClubChanged()
            closeRoute()
        }
    }

    /// "Request sent to X" with Refresh while it waits; "You weren't accepted to X" once declined.
    private func requestStatus(_ request: ClubService.JoinRequest) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
        return HStack(alignment: .top, spacing: Tokens.Spacing.gap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.isDeclined ? "You weren't accepted to \(request.club.name)" : "Request sent to \(request.club.name)")
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(request.isDeclined ? Tokens.System.error : Tokens.Ink.primary)
                Text(request.isDeclined
                     ? "Choose it again to ask again, or pick another club."
                     : "Waiting for an admin to accept you. This page updates by itself.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer(minLength: 0)
            if !request.isDeclined {
                Button("Refresh") { Task { await refreshMembership() } }
                    .buttonStyle(.rpPill(isOn: false))
            }
        }
        .padding(Tokens.Spacing.card)
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(request.isDeclined ? Tokens.System.error.opacity(0.5) : Tokens.Surface.line, lineWidth: 1) }
    }
}

#Preview {
    ClubSearchView()
        .environment(AuthState())
}
