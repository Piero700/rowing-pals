//
//  ErgEventDetailViewModel.swift
//  Rowing Pals
//

import Foundation

/// One erg event's page (decision 91): the event, its board and where you are on it.
@MainActor
@Observable
final class ErgEventDetailViewModel {
    let eventId: UUID

    private(set) var event: ErgEvent?
    private(set) var board: [ErgEventResult] = []
    private(set) var canEdit = false
    private(set) var viewerId: UUID?
    private(set) var viewerIsRower = true
    private(set) var hasLoaded = false
    var errorMessage: String?

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            viewerId = viewer.userId
            viewerIsRower = viewer.isRower
            async let eventTask = ErgEventService.event(eventId)
            async let canEditTask = ChallengeService.canSet()
            let (loaded, allowed) = try await (eventTask, canEditTask)
            event = loaded
            canEdit = allowed
            board = try await ErgEventService.board(of: loaded)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the event. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    /// Your place on the board, 1 being first.
    var myPlace: Int? { board.firstIndex { $0.userId == viewerId }.map { $0 + 1 } }
}
