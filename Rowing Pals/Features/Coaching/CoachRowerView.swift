//
//  CoachRowerView.swift
//  Rowing Pals
//

import PaceEngine
import SwiftUI

/// One rower, as their coach sees them (CoachRower, decisions 35, 39, 40): who they are with
/// their age, bodyweight and whether the account is private; anything flagged; this week; eight
/// weeks of volume; the last four weeks' zone mix; effort over eight weeks; their tests with
/// watts and W/kg (W/kg only here, decision 35); and their posts. Read-only — a coach can't
/// comment on a post they see only because they coach the rower (decision 40).
///
/// Attendance (this term's register) arrives with practices in Phase 3.
struct CoachRowerView: View {
    @State private var viewModel: CoachRowerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(userId: UUID) {
        _viewModel = State(initialValue: CoachRowerViewModel(userId: userId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let detail = viewModel.detail {
                    content(detail)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Rower") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func content(_ detail: CoachingService.RowerDetail) -> some View {
        let rower = detail.rower
        identity(detail)

        ForEach(rower.flags, id: \.self) { flag in
            flagCard(flag)
                .padding(.top, Tokens.Spacing.loose)
        }

        weekStats(detail)
            .padding(.top, Tokens.Spacing.loose)

        section("Weekly volume · 8 weeks")
        VolumeBars(weeks: detail.weeklyMetres, weekStarts: detail.weekStarts)
            .padding(Tokens.Spacing.card)
            .background(card)

        section("Zone mix · last 4 weeks")
        ZoneMixBar(shares: detail.zoneMix)
            .padding(Tokens.Spacing.card)
            .background(card)

        section("Effort trend", trailing: detail.monthEffort == nil ? nil : "Dashed: 4-week average")
        effortCard(detail)

        section("Tests")
        testsCard(detail)

        section("Posts")
        postsGrid(detail.posts)
    }

    // MARK: - Identity

    private func identity(_ detail: CoachingService.RowerDetail) -> some View {
        let rower = detail.rower
        return VStack(spacing: 0) {
            AvatarPlaceholder(diameter: Tokens.Size.rowerPageAvatar, name: rower.displayName, userId: rower.id)
            Text(rower.displayName)
                .textStyle(Typography.profileName)
                .foregroundStyle(Tokens.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.top, Tokens.Spacing.loose)
            Text(CoachRowerText.subtitle(rower))
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 4)
            HStack(spacing: 6) {
                if let age = detail.age { FlagChip(text: "Age \(age)") }
                if let weight = detail.weightKg { FlagChip(text: String(format: "%.1f kg", weight)) }
                if rower.isPrivate { FlagChip(text: "Private account") }
            }
            .padding(.top, Tokens.Spacing.loose)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Spacing.tight)
    }

    private func flagCard(_ flag: CoachFlag) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.loose) {
            Image(systemName: flag.isWarning ? "exclamationmark.triangle" : "tag")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(flag.isWarning ? Tokens.System.error : Tokens.Ink.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(flag.title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(flag.isWarning ? Tokens.System.error : Tokens.Ink.primary)
                Text(flag.detailText)
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.card)
        .background {
            Self.cardShape.fill(Tokens.Surface.card)
            if flag.isWarning {
                Self.cardShape.fill(Tokens.System.error.opacity(Tokens.Coaching.flagCardTint))
            }
        }
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    // MARK: - This week

    private func weekStats(_ detail: CoachingService.RowerDetail) -> some View {
        let rower = detail.rower
        return VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack(alignment: .top, spacing: 4) {
                stat(CoachRowerText.km(rower.weekMetres), "of \(CoachRowerText.km(rower.weeklyTargetM, decimals: false)) km", isAlert: rower.isBehindTarget)
                stat("\(rower.weekSessions)", rower.weekSessions == 1 ? "session" : "sessions")
                stat(CoachRowerText.predictedTime(rower.prediction) ?? "—",
                     CoachRowerText.range(rower.prediction).map { "pred. \($0)" } ?? "pred.")
            }
            TargetBar(metres: rower.weekMetres, target: rower.weeklyTargetM, isBehind: rower.isBehindTarget)
        }
        .padding(Tokens.Spacing.card)
        .background(card)
    }

    private func stat(_ value: String, _ label: String, isAlert: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .textStyle(Typography.coachStatSmall)
                .tabularNumerals()
                .foregroundStyle(isAlert ? Tokens.System.error : Tokens.Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Effort

    private func effortCard(_ detail: CoachingService.RowerDetail) -> some View {
        let isElevated = detail.rower.flags.contains { if case .elevatedEffort = $0 { true } else { false } }
        return VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack {
                Text("Average effort per session")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                Spacer(minLength: Tokens.Spacing.tight)
                Text(detail.recentEffort.map { String(format: "%.1f / 10", $0) } ?? "No ratings this week")
                    .font(Typography.meta.font.weight(.bold))
                    .tabularNumerals()
                    .foregroundStyle(isElevated ? Tokens.System.error : Tokens.Ink.primary)
            }
            if detail.weeklyEffort.contains(where: { $0 != nil }) {
                EffortTrendChart(weeks: detail.weeklyEffort, average: detail.monthEffort, isElevated: isElevated)
            } else {
                Text("No effort ratings in the last 8 weeks.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(card)
    }

    // MARK: - Tests

    @ViewBuilder
    private func testsCard(_ detail: CoachingService.RowerDetail) -> some View {
        if detail.tests.isEmpty {
            emptyCard("No test results yet.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(detail.tests.enumerated()), id: \.element.id) { index, test in
                    testRow(test, weightKg: detail.weightKg)
                        .asButton {
                            let target: StandardTest.Target = test.isDurationBased ? .duration(ms: test.timeMs) : .distance(m: test.distanceM)
                            navigate(.pbHistory(StandardTest(key: test.key, label: test.label, target: target), detail.rower.id))
                        }
                    if index < detail.tests.count - 1 {
                        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                    }
                }
            }
            .background(card)
            .clipShape(Self.cardShape)
        }
    }

    private func testRow(_ test: CoachingService.TestLine, weightKg: Double?) -> some View {
        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text(test.label)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(testDetail(test, weightKg: weightKg))
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer(minLength: 0)
            if test.isBest {
                Text("PB")
                    .textStyle(Typography.chip)
                    .foregroundStyle(Tokens.Accent.records)
                    .padding(.horizontal, 9)
                    .frame(minHeight: Tokens.Size.chip)
                    .background(Capsule().fill(Tokens.Accent.recordsSoft))
            }
            Text(test.isDurationBased ? "\(test.distanceM.formattedWithGrouping)m" : test.timeMs.formattedDurationMs)
                .textStyle(Typography.metricValue)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
        .frame(minHeight: Tokens.Size.rowCompact)
        .accessibilityElement(children: .combine)
    }

    /// "14 Sep · 434 W · 5.86 W/kg".
    private func testDetail(_ test: CoachingService.TestLine, weightKg: Double?) -> String {
        var parts = [test.setAt.formatted(.dateTime.day().month(.abbreviated))]
        if let watts = CoachingRules.watts(splitMs: test.splitMs) {
            parts.append("\(Int(watts.rounded())) W")
            if let weightKg, weightKg > 0 {
                parts.append(String(format: "%.2f W/kg", watts / weightKg))
            }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Posts

    @ViewBuilder
    private func postsGrid(_ posts: [CoachingService.PostTile]) -> some View {
        if posts.isEmpty {
            emptyCard("No posts yet.")
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(posts) { post in
                    let shape = RoundedRectangle(cornerRadius: Tokens.Coaching.postRadius, style: .continuous)
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            CachedAsyncImage(url: post.photoURL) {
                                PhotoPlaceholder(cornerRadius: Tokens.Coaching.postRadius)
                            }
                            .scaledToFill()
                        }
                        .clipShape(shape)
                        .contentShape(shape)
                        .asButton { navigate(.post(post.sessionId)) }
                        .accessibilityLabel("Post")
                }
            }
        }
    }

    // MARK: - Building blocks

    private var card: some View {
        Self.cardShape.fill(Tokens.Surface.card)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.card)
            .background(card)
    }

    private func section(_ title: String, trailing: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Tokens.Spacing.tight)
            if let trailing {
                Text(trailing)
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, Tokens.Spacing.group)
        .padding(.bottom, Tokens.Spacing.tight)
    }
}
