//
//  ReviewSheetViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase
import UIKit

/// Owns the segment list building up in the review sheet, and the final
/// write to Supabase on Post — one `sessions` row plus one `segments` row
/// per piece, uploaded only now that the user has confirmed the numbers.
///
/// Redesign phase F (docs/design/rowing-pals-redesign-handoff-v2.md §2
/// Screen 05): main-workout label, session type (Training or a test) with
/// validation, an "Include on leaderboards" switch, an extra-photo strip,
/// an always-required stroke-rate confirmation, read-only averages, and
/// manual entry. A manual session has no photos, so it is stored unverified
/// and stays personal: never on leaderboards, never a test result (decision
/// 2026-09-24).
@Observable
final class ReviewSheetViewModel {
    /// An environment photo — one with no erg monitor in it (the crew, the
    /// boathouse). Shown in the post's gallery; no numbers are taken from it.
    /// Keeps whatever the reader found, so "Read as monitor photo" can turn
    /// it into a piece if the automatic guess was wrong.
    struct GalleryPhoto: Identifiable {
        let id = UUID()
        let jpeg: Data
        var fields: ParsedMonitorFields?
    }

    /// Most environment photos one session can carry — keeps upload size and
    /// storage cost bounded.
    static let maxGalleryPhotos = 6

    /// Nil for a manual entry: no camera was used.
    let selfieJPEG: Data?
    var segments: [DraftSegment] = []
    var galleryPhotos: [GalleryPhoto] = []
    var caption = ""
    /// Who can see this post — a new choice at post time. `.everyone`
    /// (club + followers, not an app-wide public option — see
    /// `PostVisibility`) is the widest of the three, so it's the default.
    var visibility: PostVisibility = .everyone
    /// The badge text on the main split. Replaced by the test's own label
    /// when the session is posted as a test.
    var workoutLabel: WorkoutLabel = .ut2
    var sessionKind: SessionKind = .training
    /// "Include this session in your volume totals" — the leaderboards. Off
    /// still counts the session in your own profile and streak.
    var includeOnLeaderboards = true
    var isProcessingPhoto = false
    var isPosting = false
    var postError: String?

    var isManual: Bool { selfieJPEG == nil }

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

    /// The segment a session type is judged against — the Main one.
    var mainSegment: DraftSegment? { segments.first(where: { $0.label == .main }) }

    /// What the "Session type" dropdown offers. A manual entry can only be
    /// Training: there is no photo to prove a test.
    var availableKinds: [SessionKind] { isManual ? [.training] : SessionKind.allCases }

    /// Why the chosen session type can't be posted right now, if it can't.
    var sessionKindProblem: String? {
        guard let test = sessionKind.test else { return nil }
        guard let main = mainSegment else { return "Label one piece as Main to post a \(test.label) test." }
        return sessionKind.problem(distanceM: main.distanceM, timeMs: main.timeMs)
    }

    /// Photographed segments whose stroke rate hasn't been checked yet.
    var hasUnconfirmedRate: Bool { segments.contains { !$0.isRateConfirmed } }

    /// The first reason Post is unavailable, shown next to the button. Nil
    /// when the session can be posted.
    var postBlocker: String? {
        if segments.isEmpty { return "Add a piece to post." }
        if segments.contains(where: { $0.distanceM <= 0 || $0.timeMs <= 0 }) {
            return "Enter a distance and time for every piece."
        }
        if segments.contains(where: { $0.rate <= 0 }) {
            return "Enter the stroke rate for every piece."
        }
        if hasUnconfirmedRate { return "Confirm the stroke rate before posting." }
        return sessionKindProblem
    }

    var canPost: Bool { postBlocker == nil && !isPosting }

    /// The standard test the Main segment currently matches, if any — re-read
    /// live off `segments`, so editing a field can make the suggestion
    /// appear, change which distance it names, or disappear again. Only a
    /// suggestion: nothing enters the test rankings until the rower chooses
    /// it.
    var detectedTest: StandardTest? {
        guard !isManual, let main = mainSegment else { return nil }
        return StandardTest.match(distanceM: main.distanceM, timeMs: main.timeMs)
    }

    /// Which test key the user has already answered Yes/No for — so editing
    /// the Main segment into a *different* standard distance re-prompts,
    /// rather than silently keeping a stale decision.
    private var decidedTestKey: String?

    /// Whether the highlighted "this looks like a test" suggestion shows.
    var showsTestPrompt: Bool {
        sessionKind == .training && detectedTest != nil && detectedTest?.key != decidedTestKey
    }

    /// A photographed session starts with the selfie; a manual one with a
    /// single blank piece to type into.
    init(selfieJPEG: Data?) {
        self.selfieJPEG = selfieJPEG
        if selfieJPEG == nil {
            segments = [DraftSegment(manualLabel: .main)]
        }
    }

    /// The piece that leads the post on the feed (docs/design/v2-decisions.md
    /// #10): for a test, the Main piece; otherwise the fastest average split
    /// among pieces that aren't warm-up or cool-down, earliest on a tie. Falls
    /// back to Main, then the first piece, when nothing qualifies.
    var leadSegmentID: DraftSegment.ID? {
        Self.leadSegmentID(in: segments, isTest: sessionKind.test != nil)
    }

    static func leadSegmentID(in segments: [DraftSegment], isTest: Bool) -> DraftSegment.ID? {
        let main = segments.first { $0.label == .main }
        if isTest, let main { return main.id }
        let candidates = segments.filter { $0.label != .warmup && $0.label != .cooldown && $0.splitMs > 0 }
        if let fastest = candidates.min(by: { $0.splitMs < $1.splitMs }) {
            return fastest.id
        }
        return main?.id ?? segments.first?.id
    }

    /// Whether a new test result beats the rower's previous best for that
    /// test: faster for a distance test, further for a timed one. With no
    /// earlier result, the first one is the best so far and counts.
    static func isNewBest(
        test: StandardTest, distanceM: Int, timeMs: Int,
        previous: [(distanceM: Int, timeMs: Int)]
    ) -> Bool {
        guard !previous.isEmpty else { return true }
        if test.isDurationBased {
            return distanceM > previous.map(\.distanceM).max() ?? 0
        }
        return timeMs < previous.map(\.timeMs).min() ?? Int.max
    }

    /// Answers the suggestion. Yes picks that test in the Session type
    /// dropdown; No hides the suggestion for that test. Nothing is written
    /// until Post.
    func decideTest(accepted: Bool) {
        decidedTestKey = detectedTest?.key
        if accepted, let test = detectedTest {
            sessionKind = .test(test)
        }
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

    /// Adds a blank piece to a manual entry, e.g. a warm-up before the main
    /// piece.
    func addManualSegment() {
        segments.append(DraftSegment(manualLabel: segments.isEmpty ? .main : .extra))
    }

    func removeSegment(_ id: DraftSegment.ID) {
        segments.removeAll { $0.id == id }
    }

    /// Adds a photo from the camera or the library and decides, without
    /// asking, what it is: a monitor photo becomes a piece (its numbers read,
    /// editable, added to the total); anything else is an environment photo
    /// (docs/design/v2-decisions.md #8–9).
    @MainActor
    func addPhoto(_ jpeg: Data) async {
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }

        let fields = await Self.extractFields(from: jpeg)
        if fields.looksLikeMonitor {
            let label: SegmentLabel = segments.isEmpty ? .main : .extra
            segments.append(DraftSegment(label: label, photoJPEG: jpeg, fields: fields))
        } else if galleryPhotos.count < Self.maxGalleryPhotos {
            galleryPhotos.append(GalleryPhoto(jpeg: jpeg, fields: fields))
        }
    }

    /// Correction when a piece's photo isn't really a monitor: it moves to
    /// the environment photos and its numbers leave the total.
    func moveSegmentToGallery(_ id: DraftSegment.ID) {
        guard let index = segments.firstIndex(where: { $0.id == id }),
              let jpeg = segments[index].photoJPEG,
              galleryPhotos.count < Self.maxGalleryPhotos
        else { return }
        segments.remove(at: index)
        galleryPhotos.append(GalleryPhoto(jpeg: jpeg, fields: nil))
    }

    /// Correction the other way: an environment photo that is a monitor
    /// becomes a piece, pre-filled with whatever the reader managed (often
    /// nothing, so the rower types the numbers).
    func readGalleryPhotoAsMonitor(_ id: GalleryPhoto.ID) {
        guard let index = galleryPhotos.firstIndex(where: { $0.id == id }) else { return }
        let photo = galleryPhotos.remove(at: index)
        let empty = ParsedMonitorFields(elapsedTimeMs: .empty, distanceM: .empty, splitMs: .empty, rate: .empty)
        let label: SegmentLabel = segments.isEmpty ? .main : .extra
        segments.append(DraftSegment(label: label, photoJPEG: photo.jpeg, fields: photo.fields ?? empty))
    }

    func addGalleryPhoto(_ jpeg: Data) {
        galleryPhotos.append(GalleryPhoto(jpeg: jpeg, fields: nil))
    }

    func removeGalleryPhoto(_ id: GalleryPhoto.ID) {
        galleryPhotos.removeAll { $0.id == id }
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
        let visibility: PostVisibility
        let workoutLabel: String
        let totalDistanceM: Int
        let totalTimeMs: Int
        let avgSplitMs: Int?
        let avgRate: Double?
        let photoVerified: Bool
        let loggedLate: Bool
        let capturedAt: Date
        let sessionDate: String
        let isNewPB: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case type, caption, visibility
            case isNewPB = "is_new_pb"
            case workoutLabel = "workout_label"
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
        /// Nil for a manual piece — there is no monitor photo.
        let monitorPhotoPath: String?
        /// Nil for a manual piece — nothing was read, so there is no
        /// confidence to record (`segments.ocr_confidence` is nullable).
        let ocrConfidence: Double?
        let wasEdited: Bool
        let isLead: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case isLead = "is_lead"
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

    private struct NewSessionPhoto: Encodable {
        let sessionId: UUID
        let position: Int
        let path: String

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case position, path
        }
    }

    /// Written only when the rower chose a test in the Session type
    /// dropdown. `genderAtTime`/`categoryAtTime` are snapshots of the
    /// profile *at post time*, not a join — docs/schema.sql: reading them
    /// live would let a later profile edit silently rewrite history and the
    /// rankings.
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

    /// Uploads the selfie, every segment's monitor photo and the gallery
    /// photos, then inserts the `sessions` row, its `segments` and
    /// `session_photos` rows — in that order, so a failed insert never
    /// leaves orphaned storage objects with no row pointing at them, and a
    /// failed upload never leaves a DB row with a dangling photo path.
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
        let allPhotos = [selfieJPEG].compactMap { $0 }
            + segments.compactMap(\.photoJPEG)
            + galleryPhotos.map(\.jpeg)
        for jpeg in allPhotos {
            guard let image = UIImage(data: jpeg) else { continue }
            if await ImageModerationService.check(image) == .blocked {
                postError = "One of your photos couldn't be posted."
                return false
            }
        }

        do {
            let userId = try await SupabaseService.shared.auth.session.user.id
            let sessionId = UUID()

            if let selfieJPEG {
                try await StorageService.uploadSessionPhoto(selfieJPEG, bucket: "selfies", userId: userId, sessionId: sessionId)
            }

            var monitorPaths: [String?] = []
            for (index, segment) in segments.enumerated() {
                if let jpeg = segment.photoJPEG {
                    monitorPaths.append(try await StorageService.uploadSegmentPhoto(
                        jpeg, userId: userId, sessionId: sessionId, position: index
                    ))
                } else {
                    monitorPaths.append(nil)
                }
            }

            var galleryPaths: [String] = []
            for (index, photo) in galleryPhotos.enumerated() {
                galleryPaths.append(try await StorageService.uploadGalleryPhoto(
                    photo.jpeg, userId: userId, sessionId: sessionId, index: index
                ))
            }

            let formatter = DateFormatter()
            formatter.calendar = Calendar.current
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            let sessionDate = formatter.string(from: Date())

            // A new PB is only possible on a photographed test session, and is
            // judged against the rower's earlier results for that test before
            // this one is recorded (docs/design/v2-decisions.md #12).
            var isNewPB = false
            if !isManual, case .test(let test) = sessionKind, let main = mainSegment {
                struct PreviousResult: Decodable {
                    let distanceM: Int
                    let timeMs: Int
                    enum CodingKeys: String, CodingKey {
                        case distanceM = "distance_m"
                        case timeMs = "time_ms"
                    }
                }
                let previous: [PreviousResult] = try await SupabaseService.shared
                    .from("test_results")
                    .select("distance_m, time_ms")
                    .eq("user_id", value: userId)
                    .eq("distance_key", value: test.key)
                    .execute()
                    .value
                isNewPB = Self.isNewBest(
                    test: test, distanceM: main.distanceM, timeMs: main.timeMs,
                    previous: previous.map { ($0.distanceM, $0.timeMs) }
                )
            }

            let newSession = NewSession(
                id: sessionId,
                userId: userId,
                type: .erg,
                caption: caption.isEmpty ? nil : caption,
                visibility: visibility,
                workoutLabel: sessionKind.testLabel ?? workoutLabel.rawValue,
                totalDistanceM: totalDistanceM,
                totalTimeMs: totalTimeMs,
                avgSplitMs: avgSplitMs,
                avgRate: avgRate,
                photoVerified: !isManual,
                loggedLate: false,
                capturedAt: Date(),
                sessionDate: sessionDate,
                isNewPB: isNewPB
            )
            try await SupabaseService.shared.from("sessions").insert(newSession).execute()

            let leadID = leadSegmentID
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
                    ocrConfidence: segment.isManual ? nil : segment.ocrConfidence,
                    wasEdited: segment.wasEdited,
                    isLead: segment.id == leadID
                )
            }
            try await SupabaseService.shared.from("segments").insert(newSegments).execute()

            if !galleryPaths.isEmpty {
                let rows = galleryPaths.enumerated().map { index, path in
                    NewSessionPhoto(sessionId: sessionId, position: index, path: path)
                }
                try await SupabaseService.shared.from("session_photos").insert(rows).execute()
            }

            // A manual entry never ranks; a photographed one ranks unless
            // the rower switched "Include on leaderboards" off.
            let isRanked = !isManual && includeOnLeaderboards
            try await Self.addToDailyTotal(
                userId: userId, day: sessionDate, distanceM: totalDistanceM, type: .erg, isRanked: isRanked
            )

            if !isManual, case .test(let test) = sessionKind, let main = mainSegment {
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
    ///
    /// The personal columns always grow; the `ranked_*` columns the
    /// leaderboards read grow only for a ranked session.
    private struct DailyTotalUpsert: Encodable {
        let userId: UUID
        let day: String
        let distanceM: Int
        let ergDistanceM: Int
        let waterDistanceM: Int
        let sessionCount: Int
        let rankedDistanceM: Int
        let rankedErgDistanceM: Int
        let rankedWaterDistanceM: Int

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case day
            case distanceM = "distance_m"
            case ergDistanceM = "erg_distance_m"
            case waterDistanceM = "water_distance_m"
            case sessionCount = "session_count"
            case rankedDistanceM = "ranked_distance_m"
            case rankedErgDistanceM = "ranked_erg_distance_m"
            case rankedWaterDistanceM = "ranked_water_distance_m"
        }
    }

    private static func addToDailyTotal(
        userId: UUID, day: String, distanceM: Int, type: SessionType, isRanked: Bool
    ) async throws {
        let existing: [DailyTotal] = try await SupabaseService.shared
            .from("daily_totals")
            .select()
            .eq("user_id", value: userId)
            .eq("day", value: day)
            .execute()
            .value
        let current = existing.first

        let erg = type == .erg ? distanceM : 0
        let water = type == .water ? distanceM : 0
        let upsert = DailyTotalUpsert(
            userId: userId,
            day: day,
            distanceM: (current?.distanceM ?? 0) + distanceM,
            ergDistanceM: (current?.ergDistanceM ?? 0) + erg,
            waterDistanceM: (current?.waterDistanceM ?? 0) + water,
            sessionCount: (current?.sessionCount ?? 0) + 1,
            rankedDistanceM: (current?.rankedDistanceM ?? 0) + (isRanked ? distanceM : 0),
            rankedErgDistanceM: (current?.rankedErgDistanceM ?? 0) + (isRanked ? erg : 0),
            rankedWaterDistanceM: (current?.rankedWaterDistanceM ?? 0) + (isRanked ? water : 0)
        )
        try await SupabaseService.shared
            .from("daily_totals")
            .upsert(upsert, onConflict: "user_id,day")
            .execute()
    }
}
