//
//  SelfieDefault.swift
//  Rowing Pals
//

import Foundation

/// Whether Log takes a selfie (the front camera, the rower's face) with the monitor photo
/// (decision 98). Set in Settings → Logging; the Log screen starts each session from it and has
/// its own switch for that session. A per-device preference, like `PaceDisplay`. On by default,
/// as before the setting existed.
enum SelfieDefault {
    static let storageKey = "selfieByDefault"
}
