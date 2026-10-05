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
    /// The weekly target as typed, in km (decision 36); stored as whole metres.
    var weeklyTargetText = ""
    /// "I row" or "Coach only" (decision 34).
    var isRower = true
    /// For the photo at the top of Edit profile.
    var userId: UUID?
    /// Private inputs to the prediction algorithm (decision 30), never shown anywhere.
    var birthDate: Date?
    /// Bodyweight as typed, in kg; empty when not given.
    var weightText = ""
    /// Redesign phase E. Saved the moment it's toggled, not with the Save
    /// button — the prototype's privacy sheet acts immediately.
    var isPrivate = false
    var isSavingPrivacy = false

    var isLoading = false
    var isSaving = false
    var saveError: String?

    var isDeletingAccount = false
    var deleteError: String?

    /// Notifications (docs/design/v2-decisions.md #19). Each change is saved the moment
    /// it's made, like the privacy switch; nil until loaded.
    var notificationSettings: NotificationSettings?
    var notificationError: String?
    /// For "New posts from UEA Boat Club"; nil when the rower has no club.
    var clubName: String?

    /// Loaded values, to detect whether Save has anything to do.
    private var original: (displayName: String, gender: RowerGender, category: RowerCategory, weeklyTargetM: Int, isRower: Bool)?
    private var originalPrivate = AthletePrivateService.Details()

    var hasUnsavedChanges: Bool {
        guard let original else { return false }
        return displayName != original.displayName
            || gender != original.gender
            || category != original.category
            || (parsedWeeklyTargetM ?? original.weeklyTargetM) != original.weeklyTargetM
            || weeklyTargetProblem != nil
            || isRower != original.isRower
            || weightProblem != nil
            || AthletePrivateService.Details(birthDate: birthDate, weightKg: parsedWeight) != originalPrivate
    }

    private var parsedWeight: Double? {
        let text = weightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return text.isEmpty ? nil : Double(text)
    }

    /// The typed weekly target in whole metres; nil when it isn't a number.
    private var parsedWeeklyTargetM: Int? {
        let text = weeklyTargetText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let km = Double(text) else { return text.isEmpty ? 0 : nil }
        return Int((km * 1000).rounded())
    }

    /// Why the typed weekly target can't be saved, or nil.
    var weeklyTargetProblem: String? {
        guard let metres = parsedWeeklyTargetM, (0...500_000).contains(metres) else {
            return "Enter a weekly target between 0 and 500 km."
        }
        return nil
    }

    /// "60", or "42.5" for a part kilometre.
    static func kilometresString(_ metres: Int) -> String {
        metres % 1000 == 0 ? String(metres / 1000) : String(format: "%.1f", Double(metres) / 1000)
    }

    /// Why the typed weight can't be saved, or nil.
    var weightProblem: String? {
        let text = weightText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        guard let weight = parsedWeight, (25...250).contains(weight) else {
            return "Enter a weight between 25 and 250 kg."
        }
        return nil
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
            weeklyTargetText = Self.kilometresString(profile.weeklyTargetM)
            isRower = profile.isRower
            isPrivate = profile.isPrivate
            original = (profile.displayName, gender, profile.category, profile.weeklyTargetM, profile.isRower)
            // Before docs/migrations/2026-10-05-pace-engine-inputs.sql has run, there's nothing yet.
            let details = (try? await AthletePrivateService.mine()) ?? AthletePrivateService.Details()
            originalPrivate = details
            birthDate = details.birthDate
            weightText = details.weightKg.map(Self.weightString) ?? ""
            await loadNotifications(userId: id, clubId: profile.clubId)
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// The rower's row, or the defaults when they've never changed anything.
    @MainActor
    private func loadNotifications(userId: UUID, clubId: UUID?) async {
        do {
            let rows: [NotificationSettings] = try await SupabaseService.shared
                .from("notification_settings")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            notificationSettings = rows.first ?? .defaults(for: userId)
        } catch {
            notificationSettings = .defaults(for: userId)
            notificationError = "Couldn't load your notification settings. \(error.localizedDescription)"
        }
        if let clubId {
            let club: Club? = try? await SupabaseService.shared
                .from("clubs")
                .select()
                .eq("id", value: clubId)
                .single()
                .execute()
                .value
            clubName = club?.name
        }
        await PushNotificationService.shared.refreshAuthorizationStatus()
    }

    /// Applies one change at once and saves the whole row. Reverts if the save fails, so a
    /// switch never shows a choice that isn't saved.
    @MainActor
    func updateNotifications(_ change: (inout NotificationSettings) -> Void) async {
        guard let previous = notificationSettings else { return }
        var updated = previous
        change(&updated)
        guard updated != previous else { return }
        notificationSettings = updated
        notificationError = nil
        do {
            try await SupabaseService.shared
                .from("notification_settings")
                .upsert(updated, onConflict: "user_id")
                .execute()
        } catch {
            notificationSettings = previous
            notificationError = "Couldn't save that change. \(error.localizedDescription)"
        }
    }

    private struct ProfileEdit: Encodable {
        let displayName: String
        let gender: RowerGender
        let category: RowerCategory
        let weeklyTargetM: Int
        let isRower: Bool
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case gender, category
            case weeklyTargetM = "weekly_target_m"
            case isRower = "is_rower"
        }
    }

    /// "78.5", or "80" for a whole number.
    static func weightString(_ kg: Double) -> String {
        kg == kg.rounded() ? String(Int(kg)) : String(format: "%.1f", kg)
    }

    @MainActor
    func save() async {
        guard let userId, !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let problem = weightProblem ?? weeklyTargetProblem {
            saveError = problem
            return
        }
        weeklyTargetM = parsedWeeklyTargetM ?? weeklyTargetM
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
                .update(ProfileEdit(displayName: displayName, gender: gender, category: category, weeklyTargetM: weeklyTargetM, isRower: isRower))
                .eq("id", value: userId)
                .select()
                .execute()
                .value
            guard !updated.isEmpty else {
                saveError = "Nothing was saved — this account may not have a profile row yet. Try signing out and back in."
                return
            }
            let accountTypeChanged = original?.isRower != isRower
            original = (displayName, gender, category, weeklyTargetM, isRower)
            if accountTypeChanged {
                // Rankings, Crewmates and the Log button all change with it (decision 34).
                NotificationCenter.default.postRowerClubChanged()
            } else {
                // Name, gender and level feed the shared viewer context (rankings open on them).
                ViewerContext.shared.invalidate()
            }

            let details = AthletePrivateService.Details(birthDate: birthDate, weightKg: parsedWeight)
            if details != originalPrivate {
                try await AthletePrivateService.save(details)
                originalPrivate = details
            }
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
        // While still signed in: a signed-out phone must stop getting this rower's alerts.
        await PushNotificationService.shared.unregisterThisDevice()
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
