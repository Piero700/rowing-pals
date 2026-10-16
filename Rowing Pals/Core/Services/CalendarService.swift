//
//  CalendarService.swift
//  Rowing Pals
//

import Foundation
import Supabase

/// The Calendar's data (decisions 39, 68, 69; docs/migrations/2026-10-16-calendar.sql): practices,
/// a rower's answers and check-ins, the coach's register, term dates, races and events, and the
/// club's week. Writes go through the database's functions, which check who may make them and tell
/// the rowers concerned; reads go to the tables, where the database shows a coach their club's and
/// a rower their own.
enum CalendarService {
    /// What a coach fills in on New or Edit practice.
    struct PracticeDraft {
        var title: String
        var place: String
        var startsAt: Date
        var endsAt: Date
        var squadIds: Set<UUID>
        /// Every week on the same day until this day; nil for a one-off.
        var repeatUntil: Date?
        var remind: Bool
    }

    /// What a coach fills in on New race or event.
    struct EventDraft {
        var kind: EventKind
        var name: String
        var firstDay: Date
        var lastDay: Date
        var place: String
        var note: String
        var asksAvailability: Bool
        var squadIds: Set<UUID>
    }

    private static let practiceColumns = "*, practice_squads(squad_id)"
    private static let eventColumns = "*, event_squads(squad_id)"

    // MARK: - The club's week (decision 69)

    /// The day the viewer's club starts its week; Monday when there's no club, or before the
    /// calendar migration has run.
    static func weekStart() async -> WeekStart {
        nonisolated struct Row: Decodable {
            let weekStartsOn: WeekStart?
            enum CodingKeys: String, CodingKey { case weekStartsOn = "week_starts_on" }
        }
        guard let clubId = try? await ViewerContext.shared.current().clubId,
              let row: Row = try? await SupabaseService.shared
                .from("clubs").select("week_starts_on").eq("id", value: clubId).single().execute().value
        else { return .monday }
        return row.weekStartsOn ?? .monday
    }

    static func setWeekStart(_ day: WeekStart) async throws {
        struct Params: Encodable { let p_day: String }
        try await SupabaseService.shared.rpc("set_club_week_start", params: Params(p_day: day.rawValue)).execute()
    }

    // MARK: - Practices

    /// The club's practices starting in [from, to) — for its coaches.
    static func clubPractices(from: Date, to: Date) async throws -> [Practice] {
        let viewer = try await ViewerContext.shared.current()
        guard let clubId = viewer.clubId else { return [] }
        return try await SupabaseService.shared
            .from("practices").select(practiceColumns)
            .eq("club_id", value: clubId)
            .gte("starts_at", value: iso(from)).lt("starts_at", value: iso(to))
            .order("starts_at").execute().value
    }

    /// The practices for the signed-in rower starting in [from, to), cancelled ones included.
    static func myPractices(from: Date, to: Date) async throws -> [Practice] {
        struct Params: Encodable { let p_from: String; let p_to: String }
        return try await SupabaseService.shared
            .rpc("my_practices", params: Params(p_from: iso(from), p_to: iso(to))).execute().value
    }

    static func practice(_ id: UUID) async throws -> Practice {
        try await SupabaseService.shared
            .from("practices").select(practiceColumns).eq("id", value: id).single().execute().value
    }

    /// The latest earlier practice in the same series, for "Coach's mark · This shows the last practice."
    static func previousInSeries(_ practice: Practice) async throws -> Practice? {
        guard let series = practice.seriesId else { return nil }
        let rows: [Practice] = try await SupabaseService.shared
            .from("practices").select(practiceColumns)
            .eq("series_id", value: series).lt("starts_at", value: iso(practice.startsAt))
            .order("starts_at", ascending: false).limit(1).execute().value
        return rows.first
    }

    @discardableResult
    static func createPractice(_ draft: PracticeDraft, calendar: Calendar = .current) async throws -> UUID {
        struct Params: Encodable {
            let p_title: String?
            let p_place: String?
            let p_starts_at: String
            let p_ends_at: String
            let p_squads: [UUID]
            let p_repeat_until: String?
            let p_remind: Bool
            let p_time_zone: String

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_title, forKey: .p_title)
                try c.encode(p_place, forKey: .p_place)
                try c.encode(p_starts_at, forKey: .p_starts_at)
                try c.encode(p_ends_at, forKey: .p_ends_at)
                try c.encode(p_squads, forKey: .p_squads)
                try c.encode(p_repeat_until, forKey: .p_repeat_until)
                try c.encode(p_remind, forKey: .p_remind)
                try c.encode(p_time_zone, forKey: .p_time_zone)
            }
            enum Keys: String, CodingKey {
                case p_title, p_place, p_starts_at, p_ends_at, p_squads, p_repeat_until, p_remind, p_time_zone
            }
        }
        let params = Params(
            p_title: trimmed(draft.title), p_place: trimmed(draft.place),
            p_starts_at: iso(draft.startsAt), p_ends_at: iso(draft.endsAt), p_squads: Array(draft.squadIds),
            p_repeat_until: draft.repeatUntil.map { WorkoutRules.dayText($0, calendar: calendar) },
            p_remind: draft.remind, p_time_zone: calendar.timeZone.identifier
        )
        return try await SupabaseService.shared.rpc("create_practice", params: params).execute().value
    }

    /// Saves one practice, or it and the rest of its series (each keeps its own day).
    static func updatePractice(_ id: UUID, restOfSeries: Bool, _ draft: PracticeDraft, calendar: Calendar = .current) async throws {
        struct Params: Encodable {
            let p_practice: UUID
            let p_rest_of_series: Bool
            let p_title: String?
            let p_place: String?
            let p_starts_at: String
            let p_ends_at: String
            let p_squads: [UUID]
            let p_remind: Bool
            let p_time_zone: String

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_practice, forKey: .p_practice)
                try c.encode(p_rest_of_series, forKey: .p_rest_of_series)
                try c.encode(p_title, forKey: .p_title)
                try c.encode(p_place, forKey: .p_place)
                try c.encode(p_starts_at, forKey: .p_starts_at)
                try c.encode(p_ends_at, forKey: .p_ends_at)
                try c.encode(p_squads, forKey: .p_squads)
                try c.encode(p_remind, forKey: .p_remind)
                try c.encode(p_time_zone, forKey: .p_time_zone)
            }
            enum Keys: String, CodingKey {
                case p_practice, p_rest_of_series, p_title, p_place, p_starts_at, p_ends_at, p_squads, p_remind, p_time_zone
            }
        }
        try await SupabaseService.shared.rpc("update_practice", params: Params(
            p_practice: id, p_rest_of_series: restOfSeries, p_title: trimmed(draft.title), p_place: trimmed(draft.place),
            p_starts_at: iso(draft.startsAt), p_ends_at: iso(draft.endsAt), p_squads: Array(draft.squadIds),
            p_remind: draft.remind, p_time_zone: calendar.timeZone.identifier
        )).execute()
    }

    static func cancelPractice(_ id: UUID, restOfSeries: Bool) async throws {
        struct Params: Encodable { let p_practice: UUID; let p_rest_of_series: Bool }
        try await SupabaseService.shared.rpc("cancel_practice", params: Params(p_practice: id, p_rest_of_series: restOfSeries)).execute()
    }

    /// Who each practice is for (coaches only).
    static func audiences(ofPractices ids: [UUID]) async throws -> [UUID: Set<UUID>] {
        guard !ids.isEmpty else { return [:] }
        nonisolated struct Row: Decodable {
            let practiceId: UUID
            let userId: UUID
            enum CodingKeys: String, CodingKey {
                case practiceId = "practice_id"
                case userId = "user_id"
            }
        }
        struct Params: Encodable { let p_practices: [UUID] }
        let rows: [Row] = try await SupabaseService.shared
            .rpc("practice_audiences", params: Params(p_practices: ids)).execute().value
        return rows.reduce(into: [:]) { $0[$1.practiceId, default: []].insert($1.userId) }
    }

    // MARK: - Answers and check-in

    /// Answers to these practices: everyone's for a coach, your own for a rower.
    static func responses(toPractices ids: [UUID]) async throws -> [PracticeResponse] {
        guard !ids.isEmpty else { return [] }
        return try await SupabaseService.shared
            .from("attendance_responses").select("practice_id, user_id, answer, reason, checked_in_at")
            .in("practice_id", values: ids).execute().value
    }

    /// Available, Can't (with an optional reason), or nil to clear.
    static func respond(to practiceId: UUID, answer: PracticeAnswer?, reason: String? = nil) async throws {
        struct Params: Encodable {
            let p_practice: UUID
            let p_answer: String?
            let p_reason: String?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_practice, forKey: .p_practice)
                try c.encode(p_answer, forKey: .p_answer)
                try c.encode(p_reason, forKey: .p_reason)
            }
            enum Keys: String, CodingKey { case p_practice, p_answer, p_reason }
        }
        try await SupabaseService.shared.rpc("respond_practice", params: Params(
            p_practice: practiceId, p_answer: answer?.rawValue, p_reason: reason.flatMap(trimmed)
        )).execute()
    }

    static func checkIn(to practiceId: UUID) async throws {
        struct Params: Encodable { let p_practice: UUID }
        try await SupabaseService.shared.rpc("check_in_practice", params: Params(p_practice: practiceId)).execute()
    }

    // MARK: - The register

    static func marks(forPractices ids: [UUID]) async throws -> [AttendanceMark] {
        guard !ids.isEmpty else { return [] }
        return try await SupabaseService.shared
            .from("attendance_marks").select("practice_id, user_id, mark, set_by, set_at")
            .in("practice_id", values: ids).execute().value
    }

    static func markLog(forPractice id: UUID) async throws -> [AttendanceMarkLogEntry] {
        try await SupabaseService.shared
            .from("attendance_mark_log").select("practice_id, user_id, mark, set_by, set_at")
            .eq("practice_id", value: id).order("set_at").execute().value
    }

    /// Saves the register: a mark for each rower given, nil clearing one.
    static func setMarks(_ marks: [UUID: RegisterMark?], forPractice id: UUID) async throws {
        nonisolated struct Item: Encodable {
            let userId: UUID
            let mark: String?
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case mark
            }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(userId, forKey: .userId)
                try c.encode(mark, forKey: .mark)
            }
        }
        struct Params: Encodable { let p_practice: UUID; let p_marks: [Item] }
        let items = marks.map { Item(userId: $0.key, mark: $0.value?.rawValue) }
        try await SupabaseService.shared.rpc("set_attendance_marks", params: Params(p_practice: id, p_marks: items)).execute()
    }

    // MARK: - Terms

    static func terms() async throws -> [ClubTerm] {
        let viewer = try await ViewerContext.shared.current()
        guard let clubId = viewer.clubId else { return [] }
        return try await SupabaseService.shared
            .from("club_terms").select("id, name, starts_on, ends_on").eq("club_id", value: clubId)
            .order("starts_on").execute().value
    }

    @discardableResult
    static func saveTerm(id: UUID?, name: String, startsOn: Date, endsOn: Date, calendar: Calendar = .current) async throws -> UUID {
        struct Params: Encodable {
            let p_term: UUID?
            let p_name: String
            let p_starts_on: String
            let p_ends_on: String
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_term, forKey: .p_term)
                try c.encode(p_name, forKey: .p_name)
                try c.encode(p_starts_on, forKey: .p_starts_on)
                try c.encode(p_ends_on, forKey: .p_ends_on)
            }
            enum Keys: String, CodingKey { case p_term, p_name, p_starts_on, p_ends_on }
        }
        return try await SupabaseService.shared.rpc("save_club_term", params: Params(
            p_term: id, p_name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            p_starts_on: WorkoutRules.dayText(startsOn, calendar: calendar),
            p_ends_on: WorkoutRules.dayText(endsOn, calendar: calendar)
        )).execute().value
    }

    static func deleteTerm(_ id: UUID) async throws {
        struct Params: Encodable { let p_term: UUID }
        try await SupabaseService.shared.rpc("delete_club_term", params: Params(p_term: id)).execute()
    }

    // MARK: - Races and events (decision 68)

    /// The club's races and events ending on or after `fromDay` ("yyyy-MM-dd") — for coaches.
    static func clubEvents(fromDay: String) async throws -> [ClubEvent] {
        let viewer = try await ViewerContext.shared.current()
        guard let clubId = viewer.clubId else { return [] }
        return try await SupabaseService.shared
            .from("club_events").select(eventColumns).eq("club_id", value: clubId)
            .gte("last_day", value: fromDay).order("first_day").execute().value
    }

    /// The races and events for the signed-in rower that haven't finished.
    static func myEvents(fromDay: String) async throws -> [ClubEvent] {
        struct Params: Encodable { let p_from: String }
        return try await SupabaseService.shared.rpc("my_events", params: Params(p_from: fromDay)).execute().value
    }

    static func event(_ id: UUID) async throws -> ClubEvent {
        try await SupabaseService.shared
            .from("club_events").select(eventColumns).eq("id", value: id).single().execute().value
    }

    static func eventResponses(_ ids: [UUID]) async throws -> [EventResponse] {
        guard !ids.isEmpty else { return [] }
        return try await SupabaseService.shared
            .from("event_responses").select("event_id, user_id, answer, reason")
            .in("event_id", values: ids).execute().value
    }

    /// Who each event is for (coaches only).
    static func audiences(ofEvents ids: [UUID]) async throws -> [UUID: Set<UUID>] {
        guard !ids.isEmpty else { return [:] }
        nonisolated struct Row: Decodable {
            let eventId: UUID
            let userId: UUID
            enum CodingKeys: String, CodingKey {
                case eventId = "event_id"
                case userId = "user_id"
            }
        }
        struct Params: Encodable { let p_events: [UUID] }
        let rows: [Row] = try await SupabaseService.shared
            .rpc("event_audiences", params: Params(p_events: ids)).execute().value
        return rows.reduce(into: [:]) { $0[$1.eventId, default: []].insert($1.userId) }
    }

    /// "Can you race?": true, false, or nil to clear.
    static func respond(toEvent id: UUID, canCome: Bool?, reason: String? = nil) async throws {
        struct Params: Encodable {
            let p_event: UUID
            let p_answer: String?
            let p_reason: String?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                try c.encode(p_event, forKey: .p_event)
                try c.encode(p_answer, forKey: .p_answer)
                try c.encode(p_reason, forKey: .p_reason)
            }
            enum Keys: String, CodingKey { case p_event, p_answer, p_reason }
        }
        try await SupabaseService.shared.rpc("respond_event", params: Params(
            p_event: id, p_answer: canCome.map { $0 ? "yes" : "no" }, p_reason: reason.flatMap(trimmed)
        )).execute()
    }

    @discardableResult
    static func saveEvent(id: UUID?, _ draft: EventDraft, calendar: Calendar = .current) async throws -> UUID? {
        struct Params: Encodable {
            let p_event: UUID?
            let p_kind: String
            let p_name: String
            let p_first_day: String
            let p_last_day: String
            let p_place: String?
            let p_note: String?
            let p_asks_availability: Bool
            let p_squads: [UUID]
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: Keys.self)
                if let p_event { try c.encode(p_event, forKey: .p_event) }
                try c.encode(p_kind, forKey: .p_kind)
                try c.encode(p_name, forKey: .p_name)
                try c.encode(p_first_day, forKey: .p_first_day)
                try c.encode(p_last_day, forKey: .p_last_day)
                try c.encode(p_place, forKey: .p_place)
                try c.encode(p_note, forKey: .p_note)
                try c.encode(p_asks_availability, forKey: .p_asks_availability)
                try c.encode(p_squads, forKey: .p_squads)
            }
            enum Keys: String, CodingKey {
                case p_event, p_kind, p_name, p_first_day, p_last_day, p_place, p_note, p_asks_availability, p_squads
            }
        }
        let params = Params(
            p_event: id, p_kind: draft.kind.rawValue, p_name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            p_first_day: WorkoutRules.dayText(draft.firstDay, calendar: calendar),
            p_last_day: WorkoutRules.dayText(max(draft.lastDay, draft.firstDay), calendar: calendar),
            p_place: trimmed(draft.place), p_note: trimmed(draft.note),
            p_asks_availability: draft.asksAvailability, p_squads: Array(draft.squadIds)
        )
        if id == nil {
            return try await SupabaseService.shared.rpc("create_event", params: params).execute().value
        }
        try await SupabaseService.shared.rpc("update_event", params: params).execute()
        return id
    }

    static func deleteEvent(_ id: UUID) async throws {
        struct Params: Encodable { let p_event: UUID }
        try await SupabaseService.shared.rpc("delete_event", params: Params(p_event: id)).execute()
    }

    // MARK: - Helpers

    /// An instant as the database takes it, e.g. "2026-10-20T05:30:00Z".
    static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
