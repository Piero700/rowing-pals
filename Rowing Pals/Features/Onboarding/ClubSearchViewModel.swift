//
//  ClubSearchViewModel.swift
//  Rowing Pals
//

import Foundation
import Supabase

@Observable
final class ClubSearchViewModel {
    /// A club row plus its live member count. `clubs` has no member_count
    /// column (task 06 asks for one anyway), so this comes from PostgREST's
    /// embedded count over `profiles.club_id`, not a stored/cached number.
    struct ClubResult: Decodable, Identifiable {
        let id: UUID
        let name: String
        let location: String?
        private let joinPolicyValue: ClubJoinPolicy?
        private let profiles: [CountWrapper]

        /// Absent before docs/migrations/2026-09-30-clubs.sql has run: every club was open.
        var joinPolicy: ClubJoinPolicy { joinPolicyValue ?? .open }

        private enum CodingKeys: String, CodingKey {
            case id, name, location, profiles
            case joinPolicyValue = "join_policy"
        }

        var memberCount: Int { profiles.first?.count ?? 0 }

        /// v3's crest text: a club name that starts with an acronym uses it ("UEA Boat Club" →
        /// "UEA"); otherwise the first letters of up to three words ("Norwich Rowing Club" →
        /// "NRC").
        var crest: String {
            let words = name.split(separator: " ")
            if let first = words.first, (2...4).contains(first.count), first.allSatisfy(\.isUppercase) {
                return String(first)
            }
            return String(words.prefix(3).compactMap(\.first)).uppercased()
        }

        private struct CountWrapper: Decodable {
            let count: Int
        }
    }

    var searchText = "" {
        didSet { scheduleSearch() }
    }
    var results: [ClubResult] = []
    var selectedClub: ClubResult?
    var isSearching = false
    var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    init() {
        scheduleSearch()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    @MainActor
    private func runSearch() async {
        isSearching = true
        defer { isSearching = false }

        do {
            let query = SupabaseService.shared
                .from("clubs")
                .select("*, profiles(count)")

            let response: [ClubResult]
            if searchText.isEmpty {
                response = try await query.order("name").limit(20).execute().value
            } else {
                response = try await query.ilike("name", pattern: "%\(searchText)%").order("name").execute().value
            }
            guard !Task.isCancelled else { return }
            results = response
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
