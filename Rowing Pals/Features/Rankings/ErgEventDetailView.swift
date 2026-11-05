//
//  ErgEventDetailView.swift
//  Rowing Pals
//

import SwiftUI

/// One erg event (decision 91): its piece and window, how to take part while it's open, and the
/// board — each rower's best piece counted for it, fastest first for a distance (furthest for a
/// time), with their group and split. Coaches, the owner, co-owners and admins get Edit.
struct ErgEventDetailView: View {
    @State private var viewModel: ErgEventDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(eventId: UUID) {
        _viewModel = State(initialValue: ErgEventDetailViewModel(eventId: eventId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let event = viewModel.event {
                    content(event)
                } else if viewModel.hasLoaded {
                    Text(viewModel.errorMessage ?? "This event is no longer there.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.top, Tokens.Spacing.group)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Erg event") {
                dismiss()
            } trailing: {
                if viewModel.canEdit {
                    Button("Edit") { navigate(.editErgEvent(viewModel.eventId)) }
                        .buttonStyle(.rpText)
                }
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .challengesChanged)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionPosted)) { _ in
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func content(_ event: ErgEvent) -> some View {
        BrandChip(text: "Erg event · \(event.pieceLabel)")
            .padding(.top, Tokens.Spacing.loose)
        Text(event.title)
            .textStyle(Typography.bigResult)
            .foregroundStyle(Tokens.Ink.primary)
            .padding(.top, Tokens.Spacing.tight)
        Text(ChallengeText.window(event))
            .textStyle(Typography.meta)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.top, 2)
        Text(ChallengeText.when(event))
            .textStyle(Typography.meta)
            .fontWeight(.semibold)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.primary)
            .padding(.top, 2)

        if viewModel.viewerIsRower && event.isOpenForPosting(at: Date()) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Row your \(event.pieceLabel) and post it")
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Log it with the + as usual. With a \(event.pieceLabel) as the main piece, the post screen offers “Count for \(event.title)”, on already.")
                    .textStyle(Typography.meta)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
                    .guidance()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.card)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
            .padding(.top, Tokens.Spacing.loose)
        }

        HStack(alignment: .firstTextBaseline) {
            SectionTitle("Board")
            Text(boardCaption(event))
                .textStyle(Typography.statLabel)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .fixedSize()
        }
        .padding(.top, Tokens.Spacing.group)

        if viewModel.board.isEmpty {
            Text(ChallengeRules.eventStatus(event, now: Date()) == .upcoming
                 ? "Results show here once rowers post their \(event.pieceLabel)."
                 : "No results yet.")
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.board.enumerated()), id: \.element.id) { index, result in
                    if index > 0 { Rectangle().fill(Tokens.Surface.line).frame(height: 1) }
                    row(place: index + 1, result: result, event: event)
                }
            }
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .clipShape(Self.cardShape)
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
    }

    /// "9 results · you’re 2nd", "Fastest first".
    private func boardCaption(_ event: ErgEvent) -> String {
        let count = viewModel.board.count
        let place = viewModel.myPlace.map { " · you’re \(ChallengeText.ordinal($0))" } ?? ""
        return count == 0 ? (event.isRacedOnTime ? "Fastest first" : "Furthest first")
            : "\(count) result\(count == 1 ? "" : "s")\(place)"
    }

    private func row(place: Int, result: ErgEventResult, event: ErgEvent) -> some View {
        let isMine = result.userId == viewModel.viewerId
        return Button {
            navigate(.profile(result.userId))
        } label: {
            HStack(spacing: Tokens.Spacing.loose) {
                Text("\(place)")
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(place == 1 ? Tokens.Accent.rank : Tokens.Ink.secondary)
                    .frame(minWidth: 22, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMine ? "You" : result.displayName)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(isMine ? Tokens.Accent.brand : Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(ChallengeText.group(result))
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ChallengeText.result(result, event: event))
                        .textStyle(Typography.rowTitle)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(result.splitMs.formattedPace(display: paceDisplay))
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .padding(.vertical, Tokens.Spacing.loose)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle())
    }
}
