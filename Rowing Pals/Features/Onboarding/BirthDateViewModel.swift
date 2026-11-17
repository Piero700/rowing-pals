//
//  BirthDateViewModel.swift
//  Rowing Pals
//

import Foundation
import Observation

/// The one-time "Your date of birth" question (decision 107), for an account that hasn't given one:
/// everyone who signed up before the age rule, and anyone who came in with Apple or Google. Someone
/// under 13 can't use the app: they can correct the date or have the account deleted. A junior
/// (under 18) starts with no selfie on this phone; the database makes their account private.
@Observable
final class BirthDateViewModel {
    var birthDate: Date
    /// Continue waits until a date has actually been picked, so nobody taps past the starting date.
    private(set) var hasChosen = false
    private(set) var isSaving = false
    private(set) var isDeleting = false
    var errorMessage: String?
    /// The date given makes them under 13: they're asked to correct it or delete the account.
    var isShowingTooYoung = false

    /// Where the picker starts: 1 January, twenty years ago.
    static let startingDate: Date = {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date()) - 20
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }()

    init() {
        birthDate = Self.startingDate
    }

    func pick(_ date: Date) {
        birthDate = date
        hasChosen = true
        errorMessage = nil
    }

    var canContinue: Bool { hasChosen && !isSaving && !isDeleting }

    /// Saves the date; true when they can go on into the app.
    @MainActor
    func save() async -> Bool {
        guard canContinue else { return false }
        guard AgeRules.isOldEnough(bornOn: birthDate) else {
            isShowingTooYoung = true
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await AthletePrivateService.saveBirthDate(birthDate)
            if AgeRules.isJunior(bornOn: birthDate) {
                // Juniors start without a selfie on this phone (decision 107); Settings → Logging
                // turns it back on.
                UserDefaults.standard.set(false, forKey: SelfieDefault.storageKey)
            }
            // A junior's account was just made private: screens read it afresh.
            ViewerContext.shared.invalidate()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Someone under 13: their account and everything in it goes, and they're signed out.
    @MainActor
    func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await AccountService.deleteAccount()
        } catch {
            errorMessage = "Your account couldn't be deleted: \(error.localizedDescription) Please try again."
        }
    }
}
