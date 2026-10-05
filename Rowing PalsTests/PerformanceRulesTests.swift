//
//  PerformanceRulesTests.swift
//  Rowing PalsTests
//

import Foundation
import Testing
@testable import Rowing_Pals

/// Rules the speed work relies on: a photo is cached by its stored file, not by the signed link
/// (which changes every time it's issued), and a test banner's rank counts each rower's best.
@MainActor
struct PerformanceRulesTests {
    @Test func samePhotoUnderTwoSignedLinksIsOneCacheEntry() throws {
        let first = try #require(URL(string: "https://ref.supabase.co/storage/v1/object/sign/monitors/u1/s1/0.jpg?token=aaa"))
        let second = try #require(URL(string: "https://ref.supabase.co/storage/v1/object/sign/monitors/u1/s1/0.jpg?token=bbb"))
        let other = try #require(URL(string: "https://ref.supabase.co/storage/v1/object/sign/monitors/u1/s1/1.jpg?token=aaa"))
        #expect(ImageCache.key(for: first) == ImageCache.key(for: second))
        #expect(ImageCache.key(for: first) != ImageCache.key(for: other))
    }

    @Test func linksOutsideStorageKeepTheirWholeAddress() throws {
        let url = try #require(URL(string: "https://example.com/photo.jpg?size=2"))
        #expect(ImageCache.key(for: url) == url.absoluteString)
    }

    @Test func bannerRankCountsEachRowersBest() {
        let me = UUID(), tom = UUID(), ollie = UUID()
        let rows: [PostDetailViewModel.BoardRow] = [
            .init(userId: tom, distanceM: 2000, timeMs: 372_000),
            .init(userId: me, distanceM: 2000, timeMs: 390_000),
            .init(userId: me, distanceM: 2000, timeMs: 380_000),   // my best
            .init(userId: ollie, distanceM: 2000, timeMs: 385_000),
            .init(userId: ollie, distanceM: 2000, timeMs: 399_000),
        ]
        #expect(PostDetailViewModel.rank(of: tom, in: rows, isDurationBased: false) == 1)
        #expect(PostDetailViewModel.rank(of: me, in: rows, isDurationBased: false) == 2)
        #expect(PostDetailViewModel.rank(of: ollie, in: rows, isDurationBased: false) == 3)
        #expect(PostDetailViewModel.rank(of: UUID(), in: rows, isDurationBased: false) == nil)
    }

    @Test func timedTestRanksByDistance() {
        let a = UUID(), b = UUID()
        let rows: [PostDetailViewModel.BoardRow] = [
            .init(userId: a, distanceM: 8_400, timeMs: 1_800_000),
            .init(userId: b, distanceM: 8_600, timeMs: 1_800_000),
        ]
        #expect(PostDetailViewModel.rank(of: b, in: rows, isDurationBased: true) == 1)
        #expect(PostDetailViewModel.rank(of: a, in: rows, isDurationBased: true) == 2)
    }
}
