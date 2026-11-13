//
//  CaptureMode.swift
//  Rowing Pals
//

import Foundation

/// How Log takes its two photos while Selfie is on (decision 103). **Together** is one tap, both
/// cameras at the same moment. **One at a time** takes the monitor first, then a second photo on
/// its own screen. Log remembers the last one used, per device, like `InsetCorner`.
enum CaptureMode: String, CaseIterable {
    case together
    case oneAtATime

    static let storageKey = "captureMode"

    /// The last one used, for setting up the camera before the view's `@AppStorage` is readable.
    static var saved: CaptureMode {
        UserDefaults.standard.string(forKey: storageKey).flatMap(CaptureMode.init(rawValue:)) ?? .together
    }

    var label: String {
        switch self {
        case .together: "Together"
        case .oneAtATime: "One at a time"
        }
    }
}
