//
//  CaptureViewModel.swift
//  Rowing Pals
//

@preconcurrency import AVFoundation
import Supabase
import UIKit

/// Owns the rear-camera `AVCaptureSession` and drives one shutter press
/// through downscale → upload → `sessions` insert. Single camera only —
/// the front camera arrives with task 08's `AVCaptureMultiCamSession`.
@Observable
final class CaptureViewModel: NSObject {
    enum Phase: Equatable {
        case configuring
        case ready
        case capturing
        case uploading
        case done
        case failed(String)
    }

    let session = AVCaptureSession()
    var phase: Phase = .configuring

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.rowingpals.camera-session")
    // AVCapturePhotoCaptureDelegate's callback arrives on an arbitrary
    // AVFoundation-owned queue, not the main actor every other member of this
    // class defaults to — the delegate method below is `nonisolated` to
    // match, so this property (its only reader/writer) has to opt out too.
    // Not UI state, so it's excluded from Observation tracking — which also
    // lets it be `nonisolated` cleanly (the macro can't apply that to a
    // tracked property).
    @ObservationIgnored
    nonisolated(unsafe) private var photoContinuation: CheckedContinuation<Data, Error>?

    enum CaptureError: LocalizedError {
        case permissionDenied
        case deviceUnavailable
        case noPhotoData
        case downscaleFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "Camera access is off. Enable it in Settings to shoot a session."
            case .deviceUnavailable: "No rear camera is available on this device."
            case .noPhotoData: "The camera didn't return a usable photo. Try again."
            case .downscaleFailed: "Couldn't process that photo. Try again."
            }
        }
    }

    func start() {
        Task {
            let authorized = await requestCameraAccess()
            guard authorized else {
                phase = .failed(CaptureError.permissionDenied.localizedDescription)
                return
            }
            configureSession()
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            session.beginConfiguration()
            session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.phase = .failed(CaptureError.deviceUnavailable.localizedDescription) }
                return
            }
            session.addInput(input)

            guard session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.phase = .failed(CaptureError.deviceUnavailable.localizedDescription) }
                return
            }
            session.addOutput(photoOutput)

            // startRunning() must come strictly after commitConfiguration()
            // returns — calling it while a begin/commit block is still open
            // (even via a `defer` that hasn't fired yet) throws.
            session.commitConfiguration()
            session.startRunning()
            DispatchQueue.main.async { self.phase = .ready }
        }
    }

    /// Captures a photo, downscales/re-encodes it, uploads it, and inserts
    /// the `sessions` row. Placeholder distance/time — OCR arrives in task 09.
    func captureAndUpload(userId: UUID) async {
        phase = .capturing
        do {
            let rawData = try await capturePhotoData()
            guard let jpegData = Self.downscaledJPEG(from: rawData) else {
                throw CaptureError.downscaleFailed
            }

            phase = .uploading
            _ = try await StorageService.uploadMonitorPhoto(jpegData, userId: userId)
            try await insertSession(userId: userId)

            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func capturePhotoData() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            sessionQueue.async { [photoOutput] in
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private static func downscaledJPEG(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longEdge = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longEdge)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        // Without an explicit format, UIGraphicsImageRenderer defaults to the
        // device's screen scale (3x on most iPhones) — targetSize is in
        // points, so that silently renders 3x the intended pixel dimensions.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Placeholder payload for the `sessions` insert — not the full `Session`
    /// model, since the DB fills in id/posted_at/created_at itself.
    private struct NewSession: Encodable {
        let userId: UUID
        let type: SessionType
        let totalDistanceM: Int
        let totalTimeMs: Int
        let photoVerified: Bool
        let loggedLate: Bool
        let capturedAt: Date
        let sessionDate: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case type
            case totalDistanceM = "total_distance_m"
            case totalTimeMs = "total_time_ms"
            case photoVerified = "photo_verified"
            case loggedLate = "logged_late"
            case capturedAt = "captured_at"
            case sessionDate = "session_date"
        }
    }

    private func insertSession(userId: UUID) async throws {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let newSession = NewSession(
            userId: userId,
            type: .erg,
            totalDistanceM: 0,
            totalTimeMs: 0,
            photoVerified: true,
            loggedLate: false,
            capturedAt: Date(),
            sessionDate: formatter.string(from: Date())
        )

        try await SupabaseService.shared
            .from("sessions")
            .insert(newSession)
            .execute()
    }
}

extension CaptureViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            photoContinuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            photoContinuation?.resume(returning: data)
        } else {
            photoContinuation?.resume(throwing: CaptureError.noPhotoData)
        }
        photoContinuation = nil
    }
}
