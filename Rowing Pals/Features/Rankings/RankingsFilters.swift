//
//  RankingsFilters.swift
//  Rowing Pals
//

import SwiftUI
import Supabase

/// The filter axes shared by both Rankings boards (Volume and each test's board), AND'd
/// together: gender, level and who's included. Since decision 37 both open on the viewer's own
/// group — their gender and level in their club — and the Filters sheet widens it.
///
/// Deliberately no "All clubs" scope: app-wide rankings were cancelled (decision 17).
struct RankingsFilters: Equatable {
    var gender: RowerGender?   // nil = all
    var level: RowerCategory?  // nil = all
    var scope: SocialScope = .myClub

    /// Everyone in your club — what a rower with no gender on file gets.
    static let initial = RankingsFilters()

    /// "Senior men", "Women", "Novice rowers", "All rowers".
    var groupLabel: String {
        let noun: String
        switch gender {
        case .male: noun = "men"
        case .female: noun = "women"
        case nil: noun = "rowers"
        }
        switch level {
        case .senior: return "Senior \(noun)"
        case .novice: return "Novice \(noun)"
        case nil: return gender == nil ? "All rowers" : noun.capitalized
        }
    }

    var scopeLabel: String {
        switch scope {
        case .myClub: "My club"
        case .following: "Following"
        }
    }

    /// "Senior men · My club".
    var captionText: String {
        "\(groupLabel) · \(scopeLabel)"
    }
}

/// The viewer's own group, which every board opens on (decision 37), and the sheet's Reset.
struct ViewerGroup: Equatable {
    let gender: RowerGender?
    let level: RowerCategory
    let clubName: String?

    var filters: RankingsFilters {
        RankingsFilters(gender: gender, level: gender == nil ? nil : level, scope: .myClub)
    }

    /// "Opens on your own group: senior men in UEA Boat Club."
    var sentence: String {
        let group = filters.groupLabel.lowercased()
        guard let clubName else { return "Opens on your own group: \(group) in your club." }
        return "Opens on your own group: \(group) in \(clubName)."
    }

    /// Nil when the profile can't be read; the boards then fall back to `RankingsFilters.initial`.
    static func load() async -> ViewerGroup? {
        guard let viewer = try? await ViewerContext.shared.current() else { return nil }
        return ViewerGroup(gender: viewer.gender, level: viewer.category, clubName: viewer.clubName)
    }
}

/// The one glass pill a board shows in place of inline controls: a filter glyph and what's
/// selected ("Senior men · My club · Erg + water"). Opens `RankingsFiltersSheet`.
struct RankingsFiltersPill: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .textStyle(Typography.pill)
                Text(text)
                    .textStyle(Typography.pill)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .buttonStyle(.rpPill)
        .accessibilityLabel("Filters: \(text)")
    }
}

/// v4 `RankingsFilters` artboard: Reset · Filters · Done, then Gender, Level, Rowers and — on
/// Volume only — Source, each a glass segmented control, and a line naming the group the board
/// opens on.
struct RankingsFiltersSheet: View {
    @Binding var filters: RankingsFilters
    let ownGroup: ViewerGroup?
    /// Volume's erg / water choice; nil on a test board.
    var source: Binding<MetresLeaderboardViewModel.Source>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sectionTop) {
            ZStack {
                Text("Filters")
                    .textStyle(Typography.navTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Button("Reset", action: reset)
                        .buttonStyle(.rpText)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.rpText)
                }
            }

            axis("Gender", options: ["Men", "Women", "All"], selection: genderSelection)
            axis("Level", options: ["Senior", "Novice", "All"], selection: levelSelection)
            axis("Rowers", options: ["My club", "Following"], selection: scopeSelection)
            if let source {
                axis("Source", note: "Volume only", options: MetresLeaderboardViewModel.Source.allCases.map(\.label), selection: Binding(
                    get: { source.wrappedValue.rawValue },
                    set: { source.wrappedValue = MetresLeaderboardViewModel.Source(rawValue: $0) ?? .all }
                ))
            }

            if let ownGroup {
                Text(ownGroup.sentence)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, Tokens.Spacing.screen)
        .padding(.top, Tokens.Spacing.loose)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tokens.Surface.card)
        .presentationDetents([.height(source == nil ? 430 : 520)])
        .presentationDragIndicator(.visible)
    }

    private func reset() {
        filters = ownGroup?.filters ?? .initial
        source?.wrappedValue = .all
    }

    private func axis(_ title: String, note: String? = nil, options: [String], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .textStyle(Typography.overline)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer()
                if let note {
                    Text(note)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            .padding(.horizontal, 4)
            PillSegmentedControl(options: options, selection: selection)
        }
    }

    // Men | Women | All
    private var genderSelection: Binding<Int> {
        Binding(
            get: { filters.gender == .male ? 0 : (filters.gender == .female ? 1 : 2) },
            set: { filters.gender = $0 == 0 ? .male : ($0 == 1 ? .female : nil) }
        )
    }

    // Senior | Novice | All
    private var levelSelection: Binding<Int> {
        Binding(
            get: { filters.level == .senior ? 0 : (filters.level == .novice ? 1 : 2) },
            set: { filters.level = $0 == 0 ? .senior : ($0 == 1 ? .novice : nil) }
        )
    }

    // My club | Following
    private var scopeSelection: Binding<Int> {
        Binding(
            get: { filters.scope == .myClub ? 0 : 1 },
            set: { filters.scope = $0 == 0 ? .myClub : .following }
        )
    }
}
