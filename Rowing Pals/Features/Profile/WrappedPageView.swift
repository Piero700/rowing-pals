//
//  WrappedPageView.swift
//  Rowing Pals
//

import SwiftUI

/// One Season Wrapped page (decision 92), story-shaped (9:16), drawn the same on screen and in the
/// shared image: the season's name and days at the top, one big number, what's behind it, and the
/// rower's name at the foot. Behind it, a photo the rower picked for the page, shaded so the text
/// reads, or the plain card (user, 2026-11-03: photos, not a gradient). Your own dates show just the
/// days, with no "Your dates" title. The PBs page wears the records lilac; a first place in the
/// club, the rank amber.
struct WrappedPageView: View {
    let page: WrappedPage
    let wrapped: SeasonWrapped
    let period: WrappedPeriod
    let name: String
    let isSoFar: Bool
    var photo: UIImage?

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Season Wrapped")
                .textStyle(Typography.kicker)
                .foregroundStyle(tint)
            if period.termId != nil {
                Text(period.title + (isSoFar ? " so far" : ""))
                    .textStyle(Typography.profileName)
                    .foregroundStyle(Tokens.Ink.primary)
                    .padding(.top, 4)
            }
            Text(Self.days(period))
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)

            Spacer(minLength: Tokens.Spacing.group)
            content
            Spacer(minLength: Tokens.Spacing.group)

            HStack {
                Text(name)
                    .textStyle(Typography.name)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                Text("Rowing Pals")
                    .textStyle(Typography.kicker)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(Tokens.Spacing.group)
        .frame(width: Tokens.Size.wrappedCardWidth, height: Tokens.Size.wrappedCardHeight, alignment: .topLeading)
        .background {
            Self.shape.fill(Tokens.Surface.card)
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Tokens.Size.wrappedCardWidth, height: Tokens.Size.wrappedCardHeight)
                    .clipShape(Self.shape)
                Self.shape.fill(Tokens.Base.photoScrim)
            }
        }
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private var isFirstInClub: Bool { wrapped.clubPlace?.place == 1 }

    private var tint: Color {
        switch page {
        case .pbs: Tokens.Accent.records
        case .crew where isFirstInClub: Tokens.Accent.rank
        default: Tokens.Ink.secondary
        }
    }

    @ViewBuilder
    private var content: some View {
        if wrapped.isEmpty {
            hero("0", "metres so far", note: "Nothing logged in \(period.title) yet. Post a session and it starts here.")
        } else {
            switch page {
            case .season: season
            case .totals: totals
            case .streaks: streaks
            case .pbs: pbs
            case .crew: crew
            case .mix: mix
            }
        }
    }

    // MARK: - Pages

    private var season: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            hero(ChallengeText.metres(wrapped.metres), "on the erg")
            line("\(wrapped.sessions) session\(wrapped.sessions == 1 ? "" : "s") · \(wrapped.days) day\(wrapped.days == 1 ? "" : "s") rowed")
            if let best = wrapped.best2kMs {
                line("Best 2k: \(best.formattedDurationMs)")
            }
        }
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            hero(Self.hours(wrapped.timeMs), "hours on the erg")
            stat("Metres", ChallengeText.metres(wrapped.metres))
            stat("Sessions", "\(wrapped.sessions)")
            stat("Days rowed", "\(wrapped.days)")
            if wrapped.sessions > 0 {
                stat("A session, on average", (wrapped.metres / wrapped.sessions).formattedMetres)
            }
        }
    }

    private var streaks: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            hero("\(wrapped.longestStreak)", wrapped.longestStreak == 1 ? "day, your longest streak" : "days in a row, your longest streak")
            if let week = wrapped.biggestWeek {
                stat("Biggest week", "\(Self.date(week.start, "d MMM")) · \(ChallengeText.metres(week.metres))")
            }
            if let month = wrapped.busiestMonth {
                stat("Busiest month", "\(Self.date(month.start, "MMMM")) · \(ChallengeText.metres(month.metres))")
            }
        }
    }

    private var pbs: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            hero("\(wrapped.pbs.count)", wrapped.pbs.count == 1 ? "personal best" : "personal bests",
                 note: wrapped.pbs.isEmpty ? "No new PBs this time: the next test is yours." : nil)
            ForEach(Array(wrapped.pbs.suffix(4).enumerated()), id: \.offset) { _, pb in
                stat(pb.key, pb.timeMs.formattedDurationMs)
            }
            if let best = wrapped.best2kMs {
                stat("Best 2k", best.formattedDurationMs)
                if let faster = wrapped.twoKImprovementMs {
                    line("\(Self.seconds(faster)) faster than your best before")
                }
            }
        }
    }

    private var crew: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            if let place = wrapped.clubPlace {
                hero(place.place.formattedOrdinal, "of \(place.of) \(place.group) on metres")
            } else {
                hero("\(wrapped.trainedWith.count)", wrapped.trainedWith.count == 1 ? "crewmate tagged" : "crewmates tagged")
            }
            if !wrapped.trainedWith.isEmpty {
                Text("Trained with most")
                    .textStyle(Typography.kicker)
                    .foregroundStyle(Tokens.Ink.secondary)
                ForEach(wrapped.trainedWith) { mate in
                    stat(mate.name, "\(mate.sessions) session\(mate.sessions == 1 ? "" : "s")")
                }
            }
            if !wrapped.challengesDone.isEmpty {
                Text("Challenges finished")
                    .textStyle(Typography.kicker)
                    .foregroundStyle(Tokens.Ink.secondary)
                ForEach(Array(wrapped.challengesDone.prefix(3).enumerated()), id: \.offset) { _, title in
                    line("✓ \(title)")
                }
            }
        }
    }

    private var mix: some View {
        let longest = wrapped.zones.map(\.timeMs).max() ?? 1
        return VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            hero(wrapped.favouriteTime.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "—", "when you row most")
            ForEach(wrapped.zones.prefix(5)) { zone in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(zone.zone)
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                        Spacer(minLength: 0)
                        Text("\(Self.hours(zone.timeMs)) h")
                            .textStyle(Typography.rowTitle)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.primary)
                    }
                    ChallengeBar(fraction: Double(zone.timeMs) / Double(max(longest, 1)))
                }
            }
        }
    }

    // MARK: - Pieces

    private func hero(_ value: String, _ label: String, note: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .textStyle(Typography.wrappedNumber)
                .tabularNumerals()
                .foregroundStyle(page == .pbs ? Tokens.Accent.records : (page == .crew && isFirstInClub ? Tokens.Accent.rank : Tokens.Ink.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .textStyle(Typography.bodyV3)
                .foregroundStyle(Tokens.Ink.secondary)
            if let note {
                Text(note)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
                .lineLimit(1)
            Spacer(minLength: Tokens.Spacing.tight)
            Text(value)
                .textStyle(Typography.rowTitle)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .lineLimit(1)
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.bodySecondary)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.primary)
    }

    // MARK: - Text

    /// "61.4" hours.
    static func hours(_ ms: Int) -> String {
        String(format: "%.1f", Double(ms) / 3_600_000)
    }

    /// "4.2s".
    static func seconds(_ ms: Int) -> String {
        String(format: "%.1fs", Double(ms) / 1000)
    }

    /// "12 Oct – 6 Dec 2026".
    static func days(_ period: WrappedPeriod) -> String {
        "\(date(period.startsOn, "d MMM")) – \(date(period.endsOn, "d MMM yyyy"))"
    }

    static func date(_ day: String, _ pattern: String) -> String {
        guard let date = ChallengeRules.date(day, calendar: .current) else { return day }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
