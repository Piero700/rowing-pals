//
//  WrappedView.swift
//  Rowing Pals
//

import SwiftUI

/// Season Wrapped (decision 92): choose one of the club's terms or your own dates, swipe through the
/// season's pages, and share any page as a story-sized image (1080 × 1920).
struct WrappedView: View {
    @State private var viewModel: WrappedViewModel
    @State private var page = 0
    @State private var images: [WrappedPage: UIImage] = [:]
    @State private var isChoosingDates = false
    @Environment(\.dismiss) private var dismiss

    init(termId: UUID?) {
        _viewModel = State(initialValue: WrappedViewModel(termId: termId))
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.loose) {
            periodPicker
            if let wrapped = viewModel.wrapped, let period = viewModel.period {
                let pages = WrappedPage.pages(for: wrapped)
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                        GeometryReader { geometry in
                            let scale = min(geometry.size.width / Tokens.Size.wrappedCardWidth,
                                            geometry.size.height / Tokens.Size.wrappedCardHeight, 1)
                            WrappedPageView(page: item, wrapped: wrapped, period: period, name: viewModel.name, isSoFar: viewModel.isSoFar)
                                .scaleEffect(scale)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .task(id: viewModel.period) { render(pages, wrapped: wrapped, period: period) }
                shareButton(pages)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(viewModel.errorMessage ?? "Nothing to show yet.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, Tokens.Spacing.screen)
        .padding(.bottom, Tokens.Spacing.loose)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Season Wrapped") { dismiss() }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .sheet(isPresented: $isChoosingDates) { datesSheet }
    }

    // MARK: - Choosing the season

    private var periodPicker: some View {
        Menu {
            ForEach(viewModel.periods) { period in
                Button(period.title) {
                    page = 0
                    Task { await viewModel.choose(period) }
                }
            }
            Button("Your dates…") { isChoosingDates = true }
        } label: {
            HStack(spacing: Tokens.Spacing.tight) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.period?.title ?? "Choose a season")
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                    Text(viewModel.periods.isEmpty ? "Your club has no terms yet: choose your own dates."
                         : "Your club’s terms, or your own dates")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                Spacer(minLength: 0)
                RPIconView(icon: .chevronUpDown, size: Tokens.Icon.small)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.card)
            .frame(minHeight: Tokens.Size.input)
            .formFieldBox()
        }
        .accessibilityLabel("Season: \(viewModel.period?.title ?? "none"). Change")
    }

    private var datesSheet: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
            HStack {
                Text("Your dates")
                    .textStyle(Typography.selectedValue)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                Button("Cancel") { isChoosingDates = false }
                    .buttonStyle(.rpText)
            }
            FormLabel("From")
            DatePicker("From", selection: $viewModel.customStart, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .formFieldBox()
            FormLabel("To")
            DatePicker("To", selection: $viewModel.customEnd, in: viewModel.customStart..., displayedComponents: .date)
                .labelsHidden()
                .formFieldBox()
            FormFootnote("Up to a year. Both days count.")
            Button("Show my season") {
                isChoosingDates = false
                page = 0
                Task { await viewModel.useCustomDates() }
            }
            .buttonStyle(.rpPrimary)
            .disabled((Calendar.current.dateComponents([.day], from: viewModel.customStart, to: viewModel.customEnd).day ?? 0) > 366)
        }
        .padding(Tokens.Spacing.screen)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Tokens.Base.ground)
    }

    // MARK: - Sharing

    @ViewBuilder
    private func shareButton(_ pages: [WrappedPage]) -> some View {
        let current = pages.indices.contains(page) ? pages[page] : pages.first
        if let current, let image = images[current] {
            ShareLink(item: Image(uiImage: image),
                      preview: SharePreview("\(viewModel.period?.title ?? "Season") Wrapped · \(current.name)", image: Image(uiImage: image))) {
                Label("Share this page", icon: .share)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.rpPrimary)
        } else {
            Button {} label: {
                Label("Share this page", icon: .share)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.rpPrimary)
            .disabled(true)
        }
    }

    /// Each page as a 1080 × 1920 image, ready to share.
    @MainActor
    private func render(_ pages: [WrappedPage], wrapped: SeasonWrapped, period: WrappedPeriod) {
        var rendered: [WrappedPage: UIImage] = [:]
        for item in pages {
            let renderer = ImageRenderer(content: WrappedPageView(page: item, wrapped: wrapped, period: period,
                                                                  name: viewModel.name, isSoFar: viewModel.isSoFar))
            renderer.scale = 3
            if let image = renderer.uiImage { rendered[item] = image }
        }
        images = rendered
    }
}
