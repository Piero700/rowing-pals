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

    init(selfieJPEG: Data) {
        self.selfieJPEG = selfieJPEG
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
                sessionDate: formatter.string(from: Date())
            )
            try await SupabaseService.shared.from("sessions").insert(newSession).execute()

            let newSegments = segments.enumerated().map { index, segment in
                NewSegment(
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

            return true
        } catch {
            postError = error.localizedDescription
            return false
        }
    }
}
