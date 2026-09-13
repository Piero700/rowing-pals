//
//  OCRService.swift
//  Rowing Pals
//

import UIKit
import Vision

/// One recognized text block, kept with its normalized bounding box rather
/// than just the string — `MonitorParser` identifies which field a reading
/// belongs to by *where* it sits on screen, not what it says.
nonisolated struct RecognizedTextObservation {
    let text: String
    /// Vision's normalized coordinate space: origin bottom-left, 0...1 on
    /// both axes, y increasing *upward*. Callers translating this to a
    /// top-left-origin layout (UIKit, SwiftUI) must flip y themselves.
    let boundingBox: CGRect
    let confidence: Float
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "Couldn't read that image."
    }
}

nonisolated extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

nonisolated enum OCRService {
    /// Runs on-device text recognition over a monitor photo. Accurate, not
    /// fast — this only ever runs once per segment, not live. Language
    /// correction is off: it rewrites digits into words (an "8" reads as
    /// "B", a "0" as "O") and would destroy every reading. This is not
    /// optional, however tempting it looks in testing.
    static func recognizeText(in image: UIImage) async throws -> [RecognizedTextObservation] {
        guard let cgImage = image.cgImage else { throw OCRError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let results = observations.compactMap { observation -> RecognizedTextObservation? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextObservation(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }
                continuation.resume(returning: results)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            // UIImage(contentsOfFile:) reads EXIF orientation into
            // .imageOrientation, but .cgImage is the raw, un-rotated pixel
            // buffer — real phone photos of a monitor are routinely shot in
            // landscape while the monitor itself is upright, so without
            // passing this through, Vision reads sideways text badly.
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
