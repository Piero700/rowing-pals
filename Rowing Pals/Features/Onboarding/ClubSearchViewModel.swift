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
        private let profiles: [CountWrapper]

        var memberCount: Int { profiles.first?.count ?? 0 }

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
                .select("id, name, location, profiles(count)")

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
