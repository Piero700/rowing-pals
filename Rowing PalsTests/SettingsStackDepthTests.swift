//
//  SettingsStackDepthTests.swift
//  Rowing PalsTests
//

import Foundation
import SwiftUI
import Testing
@testable import Rowing_Pals

/// Opening Settings crashed the app on the iPhone (crash reports of 15 Nov 2026): building the
/// screen's view made Swift's runtime work out one enormous nested view type, and that recursion ran
/// past the end of the main thread's stack. The simulator's main thread has a far bigger stack, so it
/// never crashed there. This builds the screen on a thread whose stack is no bigger than the part of
/// an iPhone main thread left when SwiftUI asks for the view, and fails (the test run crashes) if
/// the view's type is still too deep for it.
struct SettingsStackDepthTests {
    /// The iPhone's main thread has 1 MB; UIKit and SwiftUI have used part of it by the time a sheet's
    /// body is asked for, so the view must fit in well under that.
    private static let stackBytes = 512 * 1024

    @Test func settingsBuildsOnAPhoneSizedStack() async {
        let finished = await Self.runOnSmallStack {
            _ = SettingsView().body
        }
        #expect(finished)
    }

    /// Runs `work` on a fresh thread with a small stack. The view isn't shown, only built, so calling
    /// its main-actor body from this thread is safe for the test.
    private static func runOnSmallStack(_ work: @escaping @MainActor () -> Void) async -> Bool {
        let unsafeWork = unsafeBitCast(work, to: (() -> Void).self)
        return await withCheckedContinuation { continuation in
            let thread = Thread {
                unsafeWork()
                continuation.resume(returning: true)
            }
            thread.stackSize = stackBytes
            thread.start()
        }
    }
}
