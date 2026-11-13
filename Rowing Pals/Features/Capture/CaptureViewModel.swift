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
/// fallback above, rather than a duplicate camera setup. It is also the
/// session One at a time uses (decision 103): the monitor photo on Log, then
/// the second photo, which `flipCamera()` can turn to the front camera.
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
    /// Which way a one-camera session faces after `flipCamera()`. `rearPreviewLayer` and
    /// `rearOutput` then carry the front camera: they belong to the session, not to a camera.
    private(set) var isFacingFront = false

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
            case .permissionDenied: "Camera access is off. Turn it on in Settings to take a photo."
            case .deviceUnavailable: "The camera isn’t available right now. Close any other app using it, then try again."
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

    /// Set the first time the session is configured. Setting up twice fails
    /// ("Both cameras aren't available") because the inputs are already on
    /// the session — and the screen *does* appear more than once: when the
    /// first-run permission pop-up dismisses, and when the rower comes back
    /// from the review screen. So setup happens once; every later start just
    /// resumes the running session.
    @ObservationIgnored
    private var hasStarted = false

    func start() {
        if hasStarted {
            // Coming back to retake a photo: the last capture left the phase at `.done`, whose
            // spinner would otherwise replace the shutter for good.
            if phase == .done { phase = .ready }
            resumeSession()
            return
        }
        hasStarted = true
        Task {
            let authorized = await requestCameraAccess()
            guard authorized else {
                // Allow a retry once access is granted in Settings.
                hasStarted = false
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

    /// After a failure: sets the camera up again from the start (removing anything a half-finished
    /// setup left on the session), or, once it's live, just gets it ready for the next photo.
    func retry() {
        guard rearPreviewLayer == nil else {
            resumeSession()
            phase = .ready
            return
        }
        phase = .configuring
        hasStarted = false
        isFacingFront = false
        sessionQueue.async { [session] in
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            session.commitConfiguration()
            DispatchQueue.main.async { self.start() }
        }
    }

    /// Whether the last failure was camera access being off, so the screen can offer Settings.
    var isPermissionDenied: Bool {
        phase == .failed(CaptureError.permissionDenied.localizedDescription)
    }

    /// Restarts an already-configured session that `stop()` paused.
    private func resumeSession() {
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Set on the session queue by `shutDown()`, so a setup still waiting in the queue doesn't
    /// start this session again afterwards.
    @ObservationIgnored
    nonisolated(unsafe) private var isShutDown = false

    /// Stops the session and lets go of its cameras, returning only once that's finished. Log
    /// replaces its session when the selfie or Together | One at a time changes; the next session
    /// can't run until this one has released the cameras (a two-camera session started while a
    /// one-camera session still holds the back camera never runs: no preview, and the shutter fails
    /// with "Cannot Record").
    func shutDown() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self, session] in
                self?.isShutDown = true
                if session.isRunning { session.stopRunning() }
                session.beginConfiguration()
                session.inputs.forEach { session.removeInput($0) }
                session.outputs.forEach { session.removeOutput($0) }
                session.commitConfiguration()
                continuation.resume()
            }
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

    /// TEMPORARY camera diagnostics (2026-11-13, debugging Together on the phone): remove once fixed.
    nonisolated static func debugLog(_ message: String) {
        print("[RP camera] \(message)")
    }

    private func observeRuntimeErrors() {
        let kind = isMultiCam ? "multi-cam" : (rearOnly ? "rear-only" : "single")
        Self.debugLog("session created: \(kind)")
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            Self.debugLog("RUNTIME ERROR (\(kind)): domain=\(error?.domain ?? "-") code=\(error?.code ?? 0) \(error?.localizedDescription ?? "unknown") userInfo=\(error?.userInfo ?? [:])")
            let reason = error?.localizedDescription ?? "unknown"
            self?.phase = .failed(CaptureError.runtimeError(reason).localizedDescription)
        }
        NotificationCenter.default.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: .main) { notification in
            let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int ?? -1
            Self.debugLog("INTERRUPTED (\(kind)): reason=\(reason)")
        }
        NotificationCenter.default.addObserver(forName: AVCaptureSession.didStartRunningNotification, object: session, queue: .main) { _ in
            Self.debugLog("did start running (\(kind))")
        }
        NotificationCenter.default.addObserver(forName: AVCaptureSession.didStopRunningNotification, object: session, queue: .main) { _ in
            Self.debugLog("did stop running (\(kind))")
        }
    }

    // MARK: - Multi-cam setup

    private func configureMultiCam() {
        guard let multiCamSession = session as? AVCaptureMultiCamSession else { return }

        sessionQueue.async { [weak self] in
            guard let self, !isShutDown else { return }

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

            // A camera keeps its format from the last session that used it. A one-camera session
            // (One at a time, Selfie off, Review's Add photo) leaves the back camera in its full
            // 4032 × 3024 photo format, which two cameras can't run together: the session then
            // stops with "Cannot Record" and shows no preview. So both are put on a format that
            // runs with the other camera first.
            guard Self.useMultiCamFormat(rearDevice), Self.useMultiCamFormat(frontDevice) else {
                multiCamSession.commitConfiguration()
                fail(.deviceUnavailable)
                return
            }

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
            Self.debugLog("multi-cam configured: hardwareCost=\(multiCamSession.hardwareCost) systemPressureCost=\(multiCamSession.systemPressureCost) rear=\(rearDevice.activeFormat.formatDescription.dimensions) multiCamOK=\(rearDevice.activeFormat.isMultiCamSupported) front=\(frontDevice.activeFormat.formatDescription.dimensions) multiCamOK=\(frontDevice.activeFormat.isMultiCamSupported) frontType=\(frontDevice.deviceType.rawValue)")
            multiCamSession.startRunning()
            Self.debugLog("multi-cam startRunning returned, isRunning=\(multiCamSession.isRunning)")

            DispatchQueue.main.async {
                self.rearPreviewLayer = rearLayer
                self.frontPreviewLayer = frontLayer
                self.phase = .ready
            }
        }
    }

    /// Moves a camera onto a format that can run alongside the other camera, if it isn't on one:
    /// the photo's 4:3 shape first (decision 55), then the largest. False when the camera has none
    /// or can't be changed right now.
    nonisolated private static func useMultiCamFormat(_ device: AVCaptureDevice) -> Bool {
        if device.activeFormat.isMultiCamSupported { return true }
        func size(_ format: AVCaptureDevice.Format) -> (isFourByThree: Bool, area: Int32) {
            let dimensions = format.formatDescription.dimensions
            return (dimensions.width * 3 == dimensions.height * 4, dimensions.width * dimensions.height)
        }
        let best = device.formats.filter(\.isMultiCamSupported).max { a, b in
            let (sizeA, sizeB) = (size(a), size(b))
            if sizeA.isFourByThree != sizeB.isFourByThree { return !sizeA.isFourByThree }
            return sizeA.area < sizeB.area
        }
        guard let best else { return false }
        do {
            try device.lockForConfiguration()
            device.activeFormat = best
            device.unlockForConfiguration()
            debugLog("moved \(device.position == .back ? "back" : "front") camera to multi-cam format \(best.formatDescription.dimensions)")
            return true
        } catch {
            return false
        }
    }

    // MARK: - Sequential fallback (devices without multi-cam support)

    private func configureSequentialRear() {
        sessionQueue.async { [weak self] in
            guard let self, !isShutDown else { return }

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

    /// Turns a one-camera session to the other camera, for the second photo in One at a time
    /// (decision 103). The input is swapped inside one configuration, so the session, its output
    /// and its preview layer all carry on with the new camera. If the new camera can't start, the
    /// old one goes back and the phase reports the failure.
    func flipCamera() {
        guard !isMultiCam, phase == .ready else { return }
        let toFront = !isFacingFront
        let previewLayer = rearPreviewLayer
        phase = .configuring
        sessionQueue.async { [weak self] in
            guard let self else { return }

            session.beginConfiguration()
            let current = toFront ? rearInput : frontInput
            if let current { session.removeInput(current) }

            let position: AVCaptureDevice.Position = toFront ? .front : .back
            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                if let current, session.canAddInput(current) { session.addInput(current) }
                session.commitConfiguration()
                fail(.deviceUnavailable)
                return
            }
            session.addInput(input)
            if toFront { frontInput = input } else { rearInput = input }

            // The swap builds new connections, so upright is set again for the photo and preview.
            for connection in [rearOutput.connection(with: .video), previewLayer?.connection] {
                if let connection, connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            session.commitConfiguration()

            DispatchQueue.main.async {
                self.isFacingFront = toFront
                self.phase = .ready
            }
        }
    }

    private func fail(_ error: CaptureError, line: Int = #line) {
        Self.debugLog("setup FAILED at CaptureViewModel.swift:\(line): \(error.localizedDescription)")
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
            let nsError = error as NSError
            Self.debugLog("captureInitialPair FAILED: domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription) isRunning=\(session.isRunning) userInfo=\(nsError.userInfo)")
            phase = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Captures one photo from a one-camera session (`rearOnly` mode): a monitor
    /// photo, or One at a time's second photo from whichever way it faces.
    func captureSinglePhoto() async -> Data? {
        do {
            phase = .capturingRear
            let data = try await capturePhotoData(from: rearOutput, isRear: true)
            guard let jpeg = Self.downscaledJPEG(from: data) else { throw CaptureError.downscaleFailed }
            phase = .done
            return jpeg
        } catch {
            let nsError = error as NSError
            Self.debugLog("captureSinglePhoto FAILED (front=\(isFacingFront)): domain=\(nsError.domain) code=\(nsError.code) \(nsError.localizedDescription) isRunning=\(session.isRunning) userInfo=\(nsError.userInfo)")
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
