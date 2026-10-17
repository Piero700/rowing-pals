//
//  AnnouncementEditorViewModel.swift
//  Rowing Pals
//

import Foundation

/// New or edit an announcement (CoachAnnouncementNew, CoachAnnouncementEdit; decision 75): its
/// heading, message, how long it stays on the Feed (24 hours unless the coach chooses), and for a
/// new one whether rowers get an alert. Editing adds Delete.
@MainActor
@Observable
final class AnnouncementEditorViewModel {
    let announcementId: UUID?

    var heading = ""
    var message = ""
    var duration: AnnouncementDuration = .day
    var until: Date
    var sendsAlert = true

    private(set) var existing: Announcement?
    private(set) var postedByName: String?
    private(set) var hasLoaded = false
    private(set) var isSaving = false
    var errorMessage: String?

    static let headingLimit = 80

    init(announcementId: UUID?) {
        self.announcementId = announcementId
        until = Date().addingTimeInterval(24 * 60 * 60)
        hasLoaded = announcementId == nil
    }

    var isNew: Bool { announcementId == nil }
    private var calendar: Calendar { .current }

    /// When it comes off the Feed: from now for a quick pick, or the chosen day and time.
    var expiresAt: Date { AnnouncementRules.expiry(from: Date(), duration: duration, until: until) }

    /// "Comes off the Feed Sat 18 Oct, 18:20."
    var expiryText: String { "Comes off the Feed \(AnnouncementRules.momentText(expiresAt, calendar: calendar))." }

    /// "Sarah Lin · posted Fri 16 Oct, 18:20 · on rowers’ Feeds now".
    var postedLine: String? {
        guard let existing else { return nil }
        var parts: [String] = []
        if let postedByName { parts.append(postedByName) }
        parts.append("posted \(AnnouncementRules.momentText(existing.createdAt, calendar: calendar))")
        parts.append(AnnouncementRules.isLive(existing, now: Date()) ? "on rowers’ Feeds now" : "off the Feed")
        return parts.joined(separator: " · ")
    }

    var problem: String? {
        let text = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "Give it a heading." }
        if text.count > Self.headingLimit { return "Keep the heading to \(Self.headingLimit) characters." }
        if expiresAt <= Date() { return "Choose a time in the future for it to come off the Feed." }
        return nil
    }

    func load() async {
        guard let announcementId else { return }
        do {
            let announcement = try await AnnouncementService.announcement(announcementId)
            existing = announcement
            heading = announcement.heading
            message = announcement.message ?? ""
            // An existing one keeps its own end until the coach picks another.
            duration = .custom
            until = announcement.expiresAt
            if let author = announcement.createdBy {
                postedByName = try? await CalendarService.displayName(of: author)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load the announcement. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    func save() async -> Bool {
        guard problem == nil else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            if let announcementId {
                try await AnnouncementService.update(announcementId, heading: heading, message: message, expiresAt: expiresAt)
            } else {
                try await AnnouncementService.post(heading: heading, message: message, expiresAt: expiresAt, alert: sendsAlert)
            }
            NotificationCenter.default.post(name: .announcementsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t save the announcement. \(error.localizedDescription)"
            return false
        }
    }

    func delete() async -> Bool {
        guard let announcementId else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await AnnouncementService.delete(announcementId)
            NotificationCenter.default.post(name: .announcementsChanged, object: nil)
            return true
        } catch {
            errorMessage = "Couldn’t delete the announcement. \(error.localizedDescription)"
            return false
        }
    }
}
