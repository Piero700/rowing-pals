//
//  CoachRowerViewModel.swift
//  Rowing Pals
//

import Foundation

/// One rower as their coach sees them (CoachRower, decisions 35, 39, 40): read-only.
@Observable
final class CoachRowerViewModel {
    let userId: UUID
    var detail: CoachingService.RowerDetail?
    var isLoading = false
    var errorMessage: String?

    init(userId: UUID) {
        self.userId = userId
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await CoachingService.rower(userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
