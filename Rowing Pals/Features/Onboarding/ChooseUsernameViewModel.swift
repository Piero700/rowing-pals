//
//  ChooseUsernameViewModel.swift
//  Rowing Pals
//

import Foundation

/// Choosing a username (decision 85): suggested from the name, checked as it's typed, and saved.
/// Accounts made before usernames see this the next time they open the app.
@MainActor
@Observable
final class ChooseUsernameViewModel {
    var username: String
    /// What's wrong with it, or that it's free.
    private(set) var note: String?
    private(set) var isFree = false
    private(set) var isSaving = false
    var errorMessage: String?

    init(name: String) {
        username = UsernameRules.suggestion(from: name)
    }

    var canContinue: Bool { UsernameRules.problem(with: username) == nil && !isSaving }

    func check() async {
        isFree = false
        if let problem = UsernameRules.problem(with: username) {
            note = problem
            return
        }
        guard let free = try? await UsernameService.isAvailable(username) else {
            note = nil
            return
        }
        isFree = free
        note = free ? "@\(UsernameRules.normalised(username)) is free." : "That username is taken. Try another."
    }

    /// Saves it; true when done.
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await UsernameService.set(username)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
