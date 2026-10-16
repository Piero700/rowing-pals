//
//  AttendanceTotalsViewModel.swift
//  Rowing Pals
//

import Foundation

/// Attendance totals (CoachAttendance; decision 39): over this term, the last four weeks or dates
/// the coach picks, each squad's and each rower's share of practices attended. Present and Late
/// count as attended; Excused is left out. Only practices that have started, and weren't
/// cancelled, count.
@MainActor
@Observable
final class AttendanceTotalsViewModel {
    enum Span: Int, CaseIterable {
        case term, fourWeeks, custom

        var label: String {
            switch self {
            case .term: "This term"
            case .fourWeeks: "4 weeks"
            case .custom: "Custom"
            }
        }
    }

    struct Line: Identifiable, Equatable {
        let id: UUID
        let name: String
        let detail: String
        let totals: CalendarRules.Totals
    }

    var span: Span = .term {
        didSet { if span != oldValue { Task { await loadMarks() } } }
    }
    var customFrom: Date
    var customTo: Date

    private(set) var terms: [ClubTerm] = []
    private(set) var squadLines: [Line] = []
    private(set) var rowerLines: [Line] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    private var squads: [Squad] = []
    private var members: [ClubMember] = []
    private var calendar: Calendar { .current }

    init() {
        let today = Calendar.current.startOfDay(for: Date())
        customTo = today
        customFrom = Calendar.current.date(byAdding: .day, value: -28, to: today) ?? today
    }

    var today: Date { calendar.startOfDay(for: Date()) }

    var currentTerm: ClubTerm? {
        CalendarRules.term(containing: WorkoutRules.dayText(today, calendar: calendar), in: terms)
    }

    /// "Autumn · 29 Sep – 5 Dec", or a prompt to set the term's dates.
    var termText: String {
        currentTerm.map { CalendarRules.termText($0, calendar: calendar) } ?? "No term set for today"
    }

    /// The days counted, first and last.
    var range: (from: Date, to: Date)? {
        switch span {
        case .term:
            guard let term = currentTerm, let from = WorkoutRules.day(term.startsOn, calendar: calendar) else { return nil }
            return (from, today)
        case .fourWeeks:
            return (calendar.date(byAdding: .day, value: -27, to: today) ?? today, today)
        case .custom:
            return (calendar.startOfDay(for: min(customFrom, customTo)), calendar.startOfDay(for: max(customFrom, customTo)))
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let viewer = try await ViewerContext.shared.current()
            async let termsTask = CalendarService.terms()
            async let membersTask = CalendarService.members()
            terms = try await termsTask
            members = try await membersTask
            if let clubId = viewer.clubId { squads = try await CoachingService.squads(of: clubId) }
            await loadMarks()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load attendance. \(error.localizedDescription)"
        }
        hasLoaded = true
    }

    func loadMarks() async {
        guard let range else {
            squadLines = []
            rowerLines = []
            return
        }
        do {
            let end = calendar.date(byAdding: .day, value: 1, to: range.to) ?? range.to
            let practices = try await CalendarService.clubPractices(from: range.from, to: end)
                .filter { !$0.cancelled && $0.startsAt <= Date() }
            let marks = try await CalendarService.marks(forPractices: practices.map(\.id))
            squadLines = squads.map { squad in
                let totals = CalendarRules.totals(marks, of: squad.memberIds)
                return Line(id: squad.id, name: squad.name,
                            detail: "\(totals.attended) of \(totals.counted) practices", totals: totals)
            }
            .sorted { ($0.totals.share ?? -1) > ($1.totals.share ?? -1) }
            rowerLines = members.compactMap { member in
                let totals = CalendarRules.totals(marks, of: [member.id])
                guard totals.counted > 0 else { return nil }
                let squad = squads.first { $0.memberIds.contains(member.id) }?.name
                let detail = [squad, "\(totals.attended) of \(totals.counted)"].compactMap { $0 }.joined(separator: " · ")
                return Line(id: member.id, name: member.displayName, detail: detail, totals: totals)
            }
            .sorted { ($0.totals.share ?? 0) < ($1.totals.share ?? 0) }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load attendance. \(error.localizedDescription)"
        }
    }

    func reloadTerms() async {
        terms = (try? await CalendarService.terms()) ?? terms
        await loadMarks()
    }
}
