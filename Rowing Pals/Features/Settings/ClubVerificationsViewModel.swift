//
//  ClubVerificationsViewModel.swift
//  Rowing Pals
//

import Foundation
import Observation

/// Settings → Club verifications (decision 108): the applications waiting for an admin, and the
/// ones already decided.
@Observable
final class ClubVerificationsViewModel {
    private(set) var requests: [ClubVerificationRequest] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The club being decided right now, so its buttons wait.
    private(set) var decidingClub: UUID?
    var errorMessage: String?

    var waiting: [ClubVerificationRequest] { requests.filter { $0.status == .pending } }
    var decided: [ClubVerificationRequest] { requests.filter { $0.status != .pending } }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            requests = try await ClubVerificationAdminService.requests()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func decide(_ request: ClubVerificationRequest, _ decision: ClubVerificationAdminService.Decision) async {
        decidingClub = request.clubId
        defer { decidingClub = nil }
        do {
            try await ClubVerificationAdminService.decide(request.clubId, decision)
            // Every screen showing the club's tag reads it afresh.
            NotificationCenter.default.postRowerClubChanged()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
