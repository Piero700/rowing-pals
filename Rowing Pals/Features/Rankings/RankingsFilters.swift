//
//  RankingsFilters.swift
//  Rowing Pals
//

import SwiftUI

/// The three independent, AND'd filter axes shared by both Rankings
/// sub-tabs (Volume and Test results) — see
/// docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 03. Presented
/// through one "Filters" sheet rather than inline chips, with a caption
/// line stating the composed filter.
///
/// Deliberately no "All clubs"/Global scope option, unlike the prototype —
/// the user already cancelled that tier app-wide (see `SocialScope`'s doc
/// comment: "maybe this will be for a v2"). Resurrecting it here would be a
/// silent product decision this file isn't the place to make, so `scope`
/// stays Following/My Club only, matching every other scope picker in the
/// app.
struct RankingsFilters: Equatable {
    var gender: RowerGender?   // nil = All
    var level: RowerCategory?  // nil = All
    var scope: SocialScope = .myClub

    static let initial = RankingsFilters()

    var captionText: String {
        [genderLabel, levelLabel, scope.label].joined(separator: " · ")
    }

    private var genderLabel: String {
        switch gender {
        case .male: "Male"
        case .female: "Female"
        case nil: "All genders"
        }
    }

    private var levelLabel: String {
        switch level {
        case .novice: "Novice"
        case .senior: "Senior"
        case nil: "All levels"
        }
    }
}

/// The single "Filters" chip both Rankings sub-tabs show in place of their
/// old inline chip rows, opening `RankingsFiltersSheet`.
struct RankingsFiltersButton: View {
    let filters: RankingsFilters
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                Text("Filters")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(Tokens.Ink.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Tokens.Ink.primary.opacity(0.1))
            }
        }
        .buttonStyle(.plain)
        Text(filters.captionText)
            .textStyle(Typography.bodySecondary)
            .foregroundStyle(Tokens.Ink.secondary)
    }
}

/// The sheet itself — three stacked `PillSegmentedControl`s, one per axis.
struct RankingsFiltersSheet: View {
    @Binding var filters: RankingsFilters
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Filters")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Accent.brand)
            }

            axis(title: "Gender", options: ["All", "Male", "Female"], selection: genderSelection)
            axis(title: "Level", options: ["All", "Novice", "Senior"], selection: levelSelection)
            axis(title: "Scope", options: SocialScope.allCases.map(\.label), selection: scopeSelection)

            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 4)
        .background(Tokens.Base.ground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func axis(title: String, options: [String], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Tokens.Ink.faint)
            PillSegmentedControl(options: options, selection: selection)
        }
    }

    private var genderSelection: Binding<Int> {
        Binding(
            get: { filters.gender == .male ? 1 : (filters.gender == .female ? 2 : 0) },
            set: { filters.gender = $0 == 1 ? .male : ($0 == 2 ? .female : nil) }
        )
    }

    private var levelSelection: Binding<Int> {
        Binding(
            get: { filters.level == .novice ? 1 : (filters.level == .senior ? 2 : 0) },
            set: { filters.level = $0 == 1 ? .novice : ($0 == 2 ? .senior : nil) }
        )
    }

    private var scopeSelection: Binding<Int> {
        Binding(
            get: { filters.scope.rawValue },
            set: { filters.scope = SocialScope(rawValue: $0) ?? .myClub }
        )
    }
}

#Preview {
    RankingsFiltersSheet(filters: .constant(.initial))
}
