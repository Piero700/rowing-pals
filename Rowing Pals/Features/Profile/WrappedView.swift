//
//  WrappedView.swift
//  Rowing Pals
//

import PhotosUI
import SwiftUI

/// Season Wrapped (decision 92): choose one of the club's terms or your own dates, swipe through the
/// season's pages, put a photo of your own behind any page (user, 2026-11-03), and share any page as
/// a story-sized image (1080 × 1920). The photos are kept on the phone for next time.
struct WrappedView: View {
    @State private var viewModel: WrappedViewModel
    @State private var page = 0
    @State private var images: [WrappedPage: UIImage] = [:]
    @State private var isChoosingDates = false
    @State private var photoItem: PhotosPickerItem?
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
                            WrappedPageView(page: item, wrapped: wrapped, period: period, name: viewModel.name,
                                            isSoFar: viewModel.isSoFar, photo: viewModel.photos[item])
                                .scaleEffect(scale)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .task(id: viewModel.period) { render(pages, wrapped: wrapped, period: period) }
                .onChange(of: viewModel.photos) { render(pages, wrapped: wrapped, period: period) }
                photoButtons(pages)
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
            GroupedSection(hint: "Up to a year. Both days count.") {
                GroupedRow(label: "From") {
                    DatePicker("From", selection: $viewModel.customStart, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                }
                GroupedDivider()
                GroupedRow(label: "To") {
                    DatePicker("To", selection: $viewModel.customEnd, in: viewModel.customStart..., displayedComponents: .date)
                        .labelsHidden()
                }
            }
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

    // MARK: - Photos

    /// Add a photo (or Change photo) for the page showing, and Remove photo once it has one.
    @ViewBuilder
    private func photoButtons(_ pages: [WrappedPage]) -> some View {
        let current = pages.indices.contains(page) ? pages[page] : pages.first
        if let current {
            HStack(spacing: Tokens.Spacing.tight) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(viewModel.photos[current] == nil ? "Add a photo" : "Change photo", icon: .photo)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.rpGlass)
                if viewModel.photos[current] != nil {
                    Button("Remove photo") { viewModel.setPhoto(nil, for: current) }
                        .buttonStyle(.rpText)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await usePhoto(item, for: current) }
            }
        }
    }

    /// The picked photo, scaled down to what a 1080 × 1920 page needs.
    private func usePhoto(_ item: PhotosPickerItem, for page: WrappedPage) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1920 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        viewModel.setPhoto(UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }, for: page)
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
                                                                  name: viewModel.name, isSoFar: viewModel.isSoFar,
                                                                  photo: viewModel.photos[item]))
            renderer.scale = 3
            if let image = renderer.uiImage { rendered[item] = image }
        }
        images = rendered
    }
}
