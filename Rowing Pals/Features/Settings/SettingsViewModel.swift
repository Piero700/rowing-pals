//
//  SettingsViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// Owns the editable half of Settings — display name, gender, category,
/// weekly target — plus sign out and account deletion (task 18). The
/// support-email/terms half of the screen (task 17) needs no state.
@Observable
final class SettingsViewModel {
    var displayName = ""
    var gender: RowerGender = .male
    var category: RowerCategory = .novice
    var weeklyTargetM = 20_000
    /// Redesign phase E. Saved the moment it's toggled, not with the Save
    /// button — the prototype's privacy sheet acts immediately.
    var isPrivate = false
    var isSavingPrivacy = false

    var isLoading = false
    var isSaving = false
    var saveError: String?

    var isDeletingAccount = false
    var deleteError: String?

    private var userId: UUID?
    /// Loaded values, to detect whether Save has anything to do.
    private var original: (displayName: String, gender: RowerGender, category: RowerCategory, weeklyTargetM: Int)?

    var hasUnsavedChanges: Bool {
        guard let original else { return false }
        return displayName != original.displayName
            || gender != original.gender
            || category != original.category
            || weeklyTargetM != original.weeklyTargetM
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let id = try await SupabaseService.shared.auth.session.user.id
            userId = id
            let profile: Profile = try await SupabaseService.shared
                .from("profiles")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            displayName = profile.displayName
            gender = profile.gender ?? .male
            category = profile.category
            weeklyTargetM = profile.weeklyTargetM
            isPrivate = profile.isPrivate
            original = (profile.displayName, gender, profile.category, profile.weeklyTargetM)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private struct ProfileEdit: Encodable {
        let displayName: String
        let gender: RowerGender
        let category: RowerCategory
        let weeklyTargetM: Int
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case gender, category
            case weeklyTargetM = "weekly_target_m"
        }
    }

    @MainActor
    func save() async {
        guard let userId, !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            // .select() after .update() asks PostgREST to hand back the
            // rows it actually touched (Prefer: return=representation) —
            // without it, an update matching zero rows (RLS filtered it
            // out, or the profiles row plain doesn't exist) still reports
            // success with nothing changed, which is exactly what silently
            // greyed out Save here while never actually writing anything.
            let updated: [Profile] = try await SupabaseService.shared
                .from("profiles")
                .update(ProfileEdit(displayName: displayName, gender: gender, category: category, weeklyTargetM: weeklyTargetM))
                .eq("id", value: userId)
                .select()
                .execute()
                .value
            guard !updated.isEmpty else {
                saveError = "Nothing was saved — this account may not have a profile row yet. Try signing out and back in."
                return
            }
            original = (displayName, gender, category, weeklyTargetM)
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// Switches the account private or public. Turning private hides your
    /// sessions and stats from everyone but approved followers; turning it
    /// public approves anyone waiting (both enforced by the database — see
    /// docs/migrations/2026-09-23-private-accounts.sql). Reverts the switch
    /// if the save fails, so the toggle never claims a state that isn't real.
    @MainActor
    func setPrivate(_ value: Bool) async {
        guard let userId, value != isPrivate, !isSavingPrivacy else { return }
        let previous = isPrivate
        isPrivate = value
        isSavingPrivacy = true
        defer { isSavingPrivacy = false }
        struct PrivacyEdit: Encodable {
            let isPrivate: Bool
            enum CodingKeys: String, CodingKey { case isPrivate = "is_private" }
        }
        do {
            let updated: [Profile] = try await SupabaseService.shared
                .from("profiles")
                .update(PrivacyEdit(isPrivate: value))
                .eq("id", value: userId)
                .select()
                .execute()
                .value
            guard !updated.isEmpty else {
                isPrivate = previous
                saveError = "Couldn't change your privacy setting. Try signing out and back in."
                return
            }
        } catch {
            isPrivate = previous
            saveError = error.localizedDescription
        }
    }

    @MainActor
    func signOut() async {
        try? await SupabaseService.shared.auth.signOut()
    }

    /// Deletion happens entirely server-side, in the `delete-account` Edge
    /// Function — deleting the `auth.users` row needs the service-role key,
    /// which never ships in the client (CLAUDE.md's own hard rule about
    /// secrets). That row's cascade takes every DB table with it
    /// (docs/schema.sql's foreign keys all read `on delete cascade`); the
    /// function additionally clears the two Storage buckets itself, since
    /// Storage objects aren't reachable by a DB foreign key at all.
    ///
    /// `signOut()` afterwards is not just tidiness: an admin-side user
    /// deletion doesn't revoke the caller's already-issued JWT, so without
    /// it the app would sit on a session for an account that no longer
    /// exists until that token's natural expiry.
    @MainActor
    func deleteAccount() async -> Bool {
        isDeletingAccount = true
        deleteError = nil
        defer { isDeletingAccount = false }
        do {
            try await SupabaseService.shared.functions.invoke("delete-account")
            await signOut()
            return true
        } catch {
            deleteError = error.localizedDescription
            return false
        }
    }
}
