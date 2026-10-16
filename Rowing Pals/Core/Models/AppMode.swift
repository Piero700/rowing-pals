//
//  AppMode.swift
//  Rowing Pals
//

/// The rower version or the coach version of the app (decision 67). Stored on the phone, like
/// `Appearance`: someone who rows and coaches gets back the one they used last.
enum AppMode: String {
    case rowing, coaching

    static let storageKey = "appMode"

    /// Which version opens. Only an account its club has made a coach gets the coach version:
    /// always, if it doesn't row; otherwise the one it last switched to. Everyone else rows.
    static func resolved(isCoach: Bool, isRower: Bool, preferred: AppMode) -> AppMode {
        guard isCoach else { return .rowing }
        return isRower ? preferred : .coaching
    }
}
