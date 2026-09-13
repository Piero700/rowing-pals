//
//  CaptureViewModel.swift
//  Rowing Pals
//

@preconcurrency import AVFoundation
import UIKit

/// Owns the capture session and turns shutter presses into downscaled JPEG
/// data — nothing more. Uploading and the `sessions`/`segments` writes moved
/// to `ReviewSheetViewModel` in task 10, since a session isn't final until
/// the user has confirmed its numbers.
///
/// Uses `AVCaptureMultiCamSession` for true simultaneous rear+front capture
/// where the device supports it, falling back to a single `AVCaptureSession`
/// swapped between cameras (rear photo, then front) where it doesn't — per
/// the task's explicit fallback requirement. iPhone 11 and later all support
/// multi-cam, so the fallback path is real but untested on the one device
/// available here.
///
/// `rearOnly` skips the front camera entirely, for task 10's "+ Add another
/// photo" — a session has one selfie no matter how many monitor photos it
/// has, so re-shooting the front camera for a second or third photo would be
/// pointless. It reuses the same sequential-rear code path as the multi-cam
/// fallback above, rather than a duplicate camera setup.
@Observable
final class CaptureViewModel: NSObject {
    enum Phase: Equatable {
        case configuring
        case ready
        case capturingRear
        case capturingFront
        case done
        case failed(String)
    }

    let session: AVCaptureSession
    let isMultiCam: Bool
    private let rearOnly: Bool

    var phase: Phase = .configuring
    var rearPreviewLayer: AVCaptureVideoPreviewLayer?
    /// nil until the front camera is actually live — always true once ready
    /// in multi-cam mode; only true once the sequential fallback reaches its
    /// second shot. Stays nil for the whole session in `rearOnly` mode.
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?

    private let sessionQueue = DispatchQueue(label: "com.rowingpals.camera-session")
    // Read from the nonisolated delegate callback below, alongside the two
    // continuations — immutable, so plain `nonisolated` (not `unsafe`) is
    // enough.
    nonisolated private let rearOutput = AVCapturePhotoOutput()
    nonisolated private let frontOutput = AVCapturePhotoOutput()
    private var rearInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    private var runtimeErrorObserver: NSObjectProtocol?

    // Both delegate callbacks land on an AVFoundation-owned queue, not the
    // main actor every other member of this class defaults to (this
    // module sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) — these two
    // are excluded from Observation tracking so `nonisolated` can apply.
    @ObservationIgnored
    nonisolated(unsafe) private var rearContinuation: CheckedContinuation<Data, Error>?
    @ObservationIgnored
    nonisolated(unsafe) private var frontContinuation: CheckedContinuation<Data, Error>?

    enum CaptureError: LocalizedError {
        case permissionDenied
        case deviceUnavailable
        case noPhotoData
        case downscaleFailed
        case runtimeError(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied: "Camera access is off. Enable it in Settings to shoot a session."
            case .deviceUnavailable: "Both cameras aren't available on this device."
            case .noPhotoData: "The camera didn't return a usable photo. Try again."
            case .downscaleFailed: "Couldn't process that photo. Try again."
            case .runtimeError(let reason): "Camera session stopped: \(reason)"
            }
        }
    }

    init(rearOnly: Bool = false) {
        self.rearOnly = rearOnly
        if !rearOnly && AVCaptureMultiCamSession.isMultiCamSupported {
            session = AVCaptureMultiCamSession()
            isMultiCam = true
        } else {
            session = AVCaptureSession()
            isMultiCam = false
        }
        super.init()
        observeRuntimeErrors()
    }

    func start() {
        Task {
            let authorized = await requestCameraAccess()
            guard authorized else {
                phase = .failed(CaptureError.permissionDenied.localizedDescription)
                return
            }
            if isMultiCam {
                configureMultiCam()
            } else {
                configureSequentialRear()
            }
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

    private func observeRuntimeErrors() {
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription ?? "unknown"
            self?.phase = .failed(CaptureError.runtimeError(reason).localizedDescription)
        }
    }

    // MARK: - Multi-cam setup

    private func configureMultiCam() {
        guard let multiCamSession = session as? AVCaptureMultiCamSession else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            multiCamSession.beginConfiguration()

            guard
                let rearDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let rearInput = try? AVCaptureDeviceInput(device: rearDevice),
                let frontInput = try? AVCaptureDeviceInput(device: frontDevice),
                multiCamSession.canAddInput(rearInput),
                multiCamSession.canAddInput(frontInput)
            else {
                multiCamSession.commitConfiguration()
                fail(.deviceUnavailable)
                return
            }
            multiCamSession.addInput(rearInput)
            multiCamSession.addInput(frontInput)
            self.rearInput = rearInput
            self.frontInput = frontInput

            guard
                let rearPort = rearInput.ports(for: .video, sourceDeviceType: rearDevice.deviceType, sourceDevicePosition: .back).first,
                let frontPort = frontInput.ports(for: .video, sourceDeviceType: frontDevice.deviceType, sourceDevicePosition: .front).first,
                multiCamSession.canAddOutput(rearOutput),
                multiCamSession.canAddOutput(frontOutput)
            else {
                multiCamSession.commitConfiguration()
                fail(.deviceUnavailable)
                return
            }
            multiCamSession.addOutputWithNoConnections(rearOutput)
            multiCamSession.addOutputWithNoConnections(frontOutput)

            let rearConnection = AVCaptureConnection(inputPorts: [rearPort], output: rearOutput)
            let frontConnection = AVCaptureConnection(inputPorts: [frontPort], output: frontOutput)
            guard multiCamSession.canAddConnection(rearConnection), multiCamSession.canAddConnection(frontConnection) else {
                multiCamSession.commitConfiguration()
                fail(.deviceUnavailable)
                return
            }
            multiCamSession.addConnection(rearConnection)
            multiCamSession.addConnection(frontConnection)

            let rearLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: multiCamSession)
            let frontLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: multiCamSession)
            let rearLayerConnection = AVCaptureConnection(inputPort: rearPort, videoPreviewLayer: rearLayer)
            let frontLayerConnection = AVCaptureConnection(inputPort: frontPort, videoPreviewLayer: frontLayer)
            guard multiCamSession.canAddConnection(rearLayerConnection), multiCamSession.canAddConnection(frontLayerConnection) else {
                multiCamSession.commitConfiguration()
                fail(.deviceUnavailable)
                return
            }
            multiCamSession.addConnection(rearLayerConnection)
            multiCamSession.addConnection(frontLayerConnection)

            // startRunning() must come strictly after commitConfiguration()
            // returns — see the note task 07 left about this exact ordering.
            multiCamSession.commitConfiguration()
            multiCamSession.startRunning()

            DispatchQueue.main.async {
                self.rearPreviewLayer = rearLayer
                self.frontPreviewLayer = frontLayer
                self.phase = .ready
            }
        }
    }

    // MARK: - Sequential fallback (devices without multi-cam support)

    private func configureSequentialRear() {
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
                fail(.deviceUnavailable)
                return
            }
            session.addInput(input)
            rearInput = input

            guard session.canAddOutput(rearOutput) else {
                session.commitConfiguration()
                fail(.deviceUnavailable)
                return
            }
            session.addOutput(rearOutput)

            session.commitConfiguration()
            session.startRunning()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            DispatchQueue.main.async {
                self.rearPreviewLayer = layer
                self.phase = .ready
            }
        }
    }

    /// Swaps the sequential session from the rear camera to the front one,
    /// reusing the same single `AVCaptureSession` and output.
    private func switchSequentialToFront() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else { return }

                session.beginConfiguration()
                if let rearInput { session.removeInput(rearInput) }

                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                    let input = try? AVCaptureDeviceInput(device: device),
                    session.canAddInput(input)
                else {
                    session.commitConfiguration()
                    continuation.resume(throwing: CaptureError.deviceUnavailable)
                    return
                }
                session.addInput(input)
                frontInput = input
                session.commitConfiguration()

                let layer = AVCaptureVideoPreviewLayer(session: session)
                DispatchQueue.main.async {
                    self.frontPreviewLayer = layer
                    continuation.resume()
                }
            }
        }
    }

    private func fail(_ error: CaptureError) {
        DispatchQueue.main.async { self.phase = .failed(error.localizedDescription) }
    }

    // MARK: - Capture

    /// Captures the rear (monitor) and front (selfie) photos simultaneously
    /// or sequentially, downscaled and ready to hand to the review sheet.
    /// No upload, no DB write — those happen once the user confirms the
    /// extracted numbers.
    func captureInitialPair() async -> (rear: Data, front: Data)? {
        do {
            let rearData: Data
            let frontData: Data
            if isMultiCam {
                phase = .capturingRear
                async let rear = capturePhotoData(from: rearOutput, isRear: true)
                async let front = capturePhotoData(from: frontOutput, isRear: false)
                (rearData, frontData) = try await (rear, front)
            } else {
                phase = .capturingRear
                rearData = try await capturePhotoData(from: rearOutput, isRear: true)
                phase = .capturingFront
                try await switchSequentialToFront()
                frontData = try await capturePhotoData(from: rearOutput, isRear: false)
            }

            guard
                let rearJPEG = Self.downscaledJPEG(from: rearData),
                let frontJPEG = Self.downscaledJPEG(from: frontData)
            else {
                throw CaptureError.downscaleFailed
            }

            phase = .done
            return (rearJPEG, frontJPEG)
        } catch {
            phase = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Captures a single rear-camera photo — `rearOnly` mode, for adding a
    /// second or third monitor photo to a session already in review.
    func captureMonitorPhoto() async -> Data? {
        do {
            phase = .capturingRear
            let data = try await capturePhotoData(from: rearOutput, isRear: true)
            guard let jpeg = Self.downscaledJPEG(from: data) else { throw CaptureError.downscaleFailed }
            phase = .done
            return jpeg
        } catch {
            phase = .failed(error.localizedDescription)
            return nil
        }
    }

    private func capturePhotoData(from output: AVCapturePhotoOutput, isRear: Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            if isRear {
                self.rearContinuation = continuation
            } else {
                self.frontContinuation = continuation
            }
            let settings = AVCapturePhotoSettings()
            sessionQueue.async { output.capturePhoto(with: settings, delegate: self) }
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

}

extension CaptureViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let continuation: CheckedContinuation<Data, Error>?
        if output === rearOutput {
            continuation = rearContinuation
            rearContinuation = nil
        } else {
            continuation = frontContinuation
            frontContinuation = nil
        }

        if let error {
            continuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation?.resume(returning: data)
        } else {
            continuation?.resume(throwing: CaptureError.noPhotoData)
        }
    }
}
