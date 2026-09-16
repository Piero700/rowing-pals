//
//  ReviewSheetViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase
import UIKit

/// Owns the segment list building up in the review sheet, and the final
/// write to Supabase on Post — one `sessions` row plus one `segments` row
/// per photo, uploaded only now that the user has confirmed the numbers.
@Observable
final class ReviewSheetViewModel {
    let selfieJPEG: Data
    var segments: [DraftSegment] = []
    var caption = ""
    var isProcessingPhoto = false
    var isPosting = false
    var postError: String?

    var totalDistanceM: Int { segments.reduce(0) { $0 + $1.distanceM } }
    var totalTimeMs: Int { segments.reduce(0) { $0 + $1.timeMs } }

    /// Pace per 500m over the whole session — recomputed from the segment
    /// totals, not averaged from each segment's own split, so a long slow
    /// warmup and a fast main piece weight correctly.
    var avgSplitMs: Int? {
        guard totalDistanceM > 0 else { return nil }
        return Int(Double(totalTimeMs) / (Double(totalDistanceM) / 500))
    }

    /// Distance-weighted mean stroke rate.
    var avgRate: Double? {
        guard totalDistanceM > 0 else { return nil }
        let weighted = segments.reduce(0.0) { $0 + $1.rate * Double($1.distanceM) }
        return ((weighted / Double(totalDistanceM)) * 10).rounded() / 10
    }

    var canPost: Bool { !segments.isEmpty && !isPosting }

    /// The standard test the Main segment currently matches, if any — re-read
    /// live off `segments`, so editing a field can make the prompt appear,
    /// change which distance it names, or disappear again.
    var detectedTest: StandardTest? {
        guard let main = segments.first(where: { $0.label == .main }) else { return nil }
        return StandardTest.match(distanceM: main.distanceM, timeMs: main.timeMs)
    }

    /// Which test key the user has already answered Yes/No for — so editing
    /// the Main segment into a *different* standard distance re-prompts,
    /// rather than silently keeping a stale decision.
    private var decidedTestKey: String?
    private var testAccepted = false

    /// Whether the highlighted test-detection block should show right now.
    var showsTestPrompt: Bool { detectedTest != nil && detectedTest?.key != decidedTestKey }

    init(selfieJPEG: Data) {
        self.selfieJPEG = selfieJPEG
    }

    /// Records the user's Yes/No answer to "Add it to the Xk leaderboard?".
    /// Nothing is written until Post — `test_results` needs the session and
    /// segment rows to exist first (its foreign keys aren't nullable).
    func decideTest(accepted: Bool) {
        decidedTestKey = detectedTest?.key
        testAccepted = accepted
    }

    /// Runs OCR on a freshly captured monitor photo and appends it as a new
    /// segment. The first segment defaults to Main (the common case — one
    /// photo, one piece); anything added after defaults to Extra rather than
    /// guessing which of warmup/main/cooldown it is.
    @MainActor
    func addSegment(from jpeg: Data) async {
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }

        let fields = await Self.extractFields(from: jpeg)
        let label: SegmentLabel = segments.isEmpty ? .main : .extra
        segments.append(DraftSegment(label: label, photoJPEG: jpeg, fields: fields))
    }

    func removeSegment(_ id: DraftSegment.ID) {
        segments.removeAll { $0.id == id }
    }

    private static func extractFields(from jpeg: Data) async -> ParsedMonitorFields {
        let empty = ParsedMonitorFields(elapsedTimeMs: .empty, distanceM: .empty, splitMs: .empty, rate: .empty)
        guard let image = UIImage(data: jpeg) else { return empty }
        do {
            let observations = try await OCRService.recognizeText(in: image)
            return MonitorParser.parse(observations)
        } catch {
            return empty
        }
    }

    // MARK: - Post

    /// Not the full `Session` model — the DB fills in `posted_at`/`created_at`
    /// itself. `id` is supplied so the photo uploads that precede this insert
    /// can be named after it.
    private struct NewSession: Encodable {
        let id: UUID
        let userId: UUID
        let type: SessionType
        let caption: String?
        let totalDistanceM: Int
        let totalTimeMs: Int
        let avgSplitMs: Int?
        let avgRate: Double?
        let photoVerified: Bool
        let loggedLate: Bool
        let capturedAt: Date
        let sessionDate: String

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case type, caption
            case totalDistanceM = "total_distance_m"
            case totalTimeMs = "total_time_ms"
            case avgSplitMs = "avg_split_ms"
            case avgRate = "avg_rate"
            case photoVerified = "photo_verified"
            case loggedLate = "logged_late"
            case capturedAt = "captured_at"
            case sessionDate = "session_date"
        }
    }

    private struct NewSegment: Encodable {
        /// `DraftSegment.id`, reused as the posted row's own id — so the
        /// Main segment's id is already known for `test_results.segment_id`
        /// without a round trip to read back what the insert generated.
        let id: UUID
        let sessionId: UUID
        let label: SegmentLabel
        let position: Int
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int
        let rate: Double
        let monitorPhotoPath: String
        let ocrConfidence: Double
        let wasEdited: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case sessionId = "session_id"
            case label, position
            case distanceM = "distance_m"
            case timeMs = "time_ms"
            case splitMs = "split_ms"
            case rate
            case monitorPhotoPath = "monitor_photo_path"
            case ocrConfidence = "ocr_confidence"
            case wasEdited = "was_edited"
        }
    }

    /// Written only when the user tapped Yes on the test-detection prompt.
    /// `genderAtTime`/`categoryAtTime` are snapshots of the profile *at post
    /// time*, not a join — docs/schema.sql: reading them live would let a
    /// later profile edit silently rewrite history and the rankings.
    private struct NewTestResult: Encodable {
        let userId: UUID
        let sessionId: UUID
        let segmentId: UUID
        let distanceKey: String
        let distanceM: Int
        let timeMs: Int
        let splitMs: Int
        let genderAtTime: RowerGender
        let categoryAtTime: RowerCategory

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case sessionId = "session_id"
            case segmentId = "segment_id"
            case distanceKey = "distance_key"
            case distanceM = "distance_m"
            case timeMs = "time_ms"
            case splitMs = "split_ms"
            case genderAtTime = "gender_at_time"
            case categoryAtTime = "category_at_time"
        }
    }

    /// Uploads the selfie and every segment's monitor photo, then inserts
    /// the `sessions` row and its `segments` rows — in that order, so a
    /// failed insert never leaves orphaned storage objects with no row
    /// pointing at them, and a failed upload never leaves a DB row with a
    /// dangling photo path.
    @MainActor
    func post() async -> Bool {
        guard canPost else { return false }
        isPosting = true
        postError = nil
        defer { isPosting = false }

        // Filtering, task 17: every caption and photo is checked *before*
        // anything is uploaded or written — a rejected post never reaches
        // Storage or the database at all.
        if TextFilterService.isBlocked(caption) {
            postError = "That caption isn't allowed. Please rephrase it."
            return false
        }
        for jpeg in [selfieJPEG] + segments.map(\.photoJPEG) {
            guard let image = UIImage(data: jpeg) else { continue }
            if await ImageModerationService.check(image) == .blocked {
                postError = "One of your photos couldn't be posted."
                return false
            }
        }

        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            let sessionId = UUID()

            try await StorageService.uploadSessionPhoto(selfieJPEG, bucket: "selfies", userId: userId, sessionId: sessionId)

            var monitorPaths: [String] = []
            for (index, segment) in segments.enumerated() {
                let path = try await StorageService.uploadSegmentPhoto(
                    segment.photoJPEG, userId: userId, sessionId: sessionId, position: index
                )
                monitorPaths.append(path)
            }

            let formatter = DateFormatter()
            formatter.calendar = Calendar.current
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            let sessionDate = formatter.string(from: Date())

            let newSession = NewSession(
                id: sessionId,
                userId: userId,
                type: .erg,
                caption: caption.isEmpty ? nil : caption,
                totalDistanceM: totalDistanceM,
                totalTimeMs: totalTimeMs,
                avgSplitMs: avgSplitMs,
                avgRate: avgRate,
                photoVerified: true,
                loggedLate: false,
                capturedAt: Date(),
                sessionDate: sessionDate
            )
            try await SupabaseService.shared.from("sessions").insert(newSession).execute()

            let newSegments = segments.enumerated().map { index, segment in
                NewSegment(
                    id: segment.id,
                    sessionId: sessionId,
                    label: segment.label,
                    position: index,
                    distanceM: segment.distanceM,
                    timeMs: segment.timeMs,
                    splitMs: segment.splitMs,
                    rate: segment.rate,
                    monitorPhotoPath: monitorPaths[index],
                    ocrConfidence: segment.ocrConfidence,
                    wasEdited: segment.wasEdited
                )
            }
            try await SupabaseService.shared.from("segments").insert(newSegments).execute()

            try await Self.addToDailyTotal(userId: userId, day: sessionDate, distanceM: totalDistanceM, type: .erg)

            if testAccepted, let test = detectedTest, test.key == decidedTestKey,
               let main = segments.first(where: { $0.label == .main }) {
                let profile: Profile = try await SupabaseService.shared
                    .from("profiles")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                if let gender = profile.gender {
                    let newTestResult = NewTestResult(
                        userId: userId,
                        sessionId: sessionId,
                        segmentId: main.id,
                        distanceKey: test.key,
                        distanceM: main.distanceM,
                        timeMs: main.timeMs,
                        splitMs: main.splitMs,
                        genderAtTime: gender,
                        categoryAtTime: profile.category
                    )
                    try await SupabaseService.shared.from("test_results").insert(newTestResult).execute()
                }
            }

            return true
        } catch {
            postError = error.localizedDescription
            return false
        }
    }

    /// Increments (never overwrites) the user's `daily_totals` row for this
    /// session's day. No task builds a trigger or Edge Function for this, so
    /// it happens here, client-side, right after the row it's summarizing
    /// exists — every leaderboard and profile chart reads only from this
    /// table, so a session that doesn't reach it is invisible everywhere.
    private struct DailyTotalUpsert: Encodable {
        let userId: UUID
        let day: String
        let distanceM: Int
        let ergDistanceM: Int
        let waterDistanceM: Int
        let sessionCount: Int

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case day
            case distanceM = "distance_m"
            case ergDistanceM = "erg_distance_m"
            case waterDistanceM = "water_distance_m"
            case sessionCount = "session_count"
        }
    }

    private static func addToDailyTotal(userId: UUID, day: String, distanceM: Int, type: SessionType) async throws {
        let existing: [DailyTotal] = try await SupabaseService.shared
            .from("daily_totals")
            .select()
            .eq("user_id", value: userId)
            .eq("day", value: day)
            .execute()
            .value
        let current = existing.first

        let upsert = DailyTotalUpsert(
            userId: userId,
            day: day,
            distanceM: (current?.distanceM ?? 0) + distanceM,
            ergDistanceM: (current?.ergDistanceM ?? 0) + (type == .erg ? distanceM : 0),
            waterDistanceM: (current?.waterDistanceM ?? 0) + (type == .water ? distanceM : 0),
            sessionCount: (current?.sessionCount ?? 0) + 1
        )
        try await SupabaseService.shared
            .from("daily_totals")
            .upsert(upsert, onConflict: "user_id,day")
            .execute()
    }
}
