//
//  StackProbe.swift
//  Rowing PalsTests
//

import Foundation

/// Measures how much stack a piece of work needs: it runs the work on a thread whose stack memory is
/// first filled with a marker byte, then finds the deepest byte the work overwrote. Used to see how
/// deep each screen's view type is (the Settings crash of 15 Nov 2026 was the stack running out).
enum StackProbe {
    private static let stackBytes = 8 * 1024 * 1024
    private static let marker: UInt8 = 0xA5

    private final class Job {
        let work: () -> Void
        init(_ work: @escaping () -> Void) { self.work = work }
    }

    /// The peak stack the work used, in bytes.
    static func peakBytes(_ work: @escaping @MainActor () -> Void) -> Int {
        let unsafeWork = unsafeBitCast(work, to: (() -> Void).self)
        let stack = UnsafeMutableRawPointer.allocate(byteCount: stackBytes, alignment: 16_384)
        defer { stack.deallocate() }
        stack.initializeMemory(as: UInt8.self, repeating: marker, count: stackBytes)

        var attributes = pthread_attr_t()
        pthread_attr_init(&attributes)
        defer { pthread_attr_destroy(&attributes) }
        pthread_attr_setstack(&attributes, stack, stackBytes)

        let job = Unmanaged.passRetained(Job(unsafeWork)).toOpaque()
        var thread: pthread_t?
        let created = pthread_create(&thread, &attributes, { context in
            Unmanaged<Job>.fromOpaque(context).takeRetainedValue().work()
            return nil
        }, job)
        guard created == 0, let thread else { return -1 }
        pthread_join(thread, nil)

        // The stack grows down from the top, so the lowest overwritten byte marks the peak.
        let bytes = stack.assumingMemoryBound(to: UInt8.self)
        var lowest = 0
        while lowest < stackBytes, bytes[lowest] == marker { lowest += 1 }
        return stackBytes - lowest
    }
}
