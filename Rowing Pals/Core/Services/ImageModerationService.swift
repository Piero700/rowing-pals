//
//  ImageModerationService.swift
//  Rowing Pals
//

import SensitiveContentAnalysis
import UIKit

/// Checks a photo for sensitive (nude) content before it's uploaded — App
/// Store Guideline 1.2's filtering requirement, on-device and free via
/// Apple's SensitiveContentAnalysis framework, the same on-device-only
/// approach this app already takes for OCR.
///
/// Real, documented constraints of this framework, not implementation
/// gaps: it only works on a physical device (the simulator always fails
/// the underlying system-service connection), and it only actually
/// analyzes anything when the person has turned on Settings → Privacy &
/// Security → Sensitive Content Warning — the app cannot enable that
/// setting on their behalf. Both cases fail *open* here (the photo is
/// allowed through) rather than blocking every upload because of an OS
/// setting outside the app's control; this is a real limitation to be
/// upfront about, not something to paper over.
///
/// One more, confirmed via a real Xcode signing error (task 17): a free
/// "Personal Team" Apple ID cannot provision a build that has the
/// Sensitive Content Analysis *capability* enabled at all — it needs the
/// paid Apple Developer Program membership (task 19 says to buy this
/// before doing any TestFlight work, precisely because of blockers like
/// this one). Until then the capability stays off the target, and this
/// check just always fails open, same as the two cases above — nothing
/// here needs the capability present to compile or run.
enum ImageModerationService {
    enum Result {
        case allowed
        case blocked
    }

    static func check(_ image: UIImage) async -> Result {
        guard let cgImage = image.cgImage else { return .allowed }

        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else {
            return .allowed
        }

        do {
            let response = try await analyzer.analyzeImage(cgImage)
            return response.isSensitive ? .blocked : .allowed
        } catch {
            print("Image moderation check failed, allowing the photo through: \(error)")
            return .allowed
        }
    }
}
