//
//  NextPracticeModel.swift
//  Rowing Pals
//

import Foundation

/// The Feed's practice card (RowerFeedCoaching; decision 68): the rower's next practice in the
/// coming week that hasn't finished, with their answer, which they can change from the card.
@MainActor
@Observable
final class NextPracticeModel {
    private(set) var practice: Practice?
    private(set) var answer: PracticeAnswer?
    private(set) var squadText: String?
    var errorMessage: String?

    func load() async {
        do {
            let viewer = try await ViewerContext.shared.current()
            guard viewer.isRower, let clubId = viewer.clubId else { practice = nil; return }
            let now = Date()
            let upcoming = try await CalendarService.myPractices(
                from: Calendar.current.date(byAdding: .hour, value: -6, to: now) ?? now,
                to: Calendar.current.date(byAdding: .day, value: 8, to: now) ?? now
            )
            guard let next = upcoming.first(where: { !$0.cancelled && $0.endsAt > now }) else {
                practice = nil
                return
            }
            // The RPC leaves out the squads; the practice itself has them.
            let full = (try? await CalendarService.practice(next.id)) ?? next
            let mine = try await CalendarService.responses(toPractices: [next.id]).first { $0.userId == viewer.userId }
            if full.squadIds.isEmpty {
                squadText = "Whole club"
            } else {
                let squads = (try? await CoachingService.squads(of: clubId)) ?? []
                let names = squads.filter { full.squadIds.contains($0.id) }.map(\.name)
                squadText = names.isEmpty ? nil : names.joined(separator: ", ")
            }
            practice = full
            answer = mine?.answer
            errorMessage = nil
        } catch {
            // Before the calendar migration there are no practices to show; the Feed carries on.
            practice = nil
        }
    }

    func setAnswer(_ new: PracticeAnswer) async {
        guard let practice else { return }
        let old = answer
        answer = new
        do {
            try await CalendarService.respond(to: practice.id, answer: new)
            NotificationCenter.default.post(name: .practiceAnswered, object: nil)
            errorMessage = nil
        } catch {
            answer = old
            errorMessage = "Couldn’t save that. \(error.localizedDescription)"
        }
    }
}
