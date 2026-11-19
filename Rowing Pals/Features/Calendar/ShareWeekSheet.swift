//
//  ShareWeekSheet.swift
//  Rowing Pals
//

import SwiftUI

/// "Share week" (Calendar) and "Share workout" (a workout's page), decision 110: a preview of the
/// picture, then the iPhone share screen with the picture and the sign-up link together.
struct ShareWeekSheet: View {
    @State private var viewModel: ShareWeekViewModel
    @State private var card: UIImage?
    @State private var isSharing = false
    @Environment(\.dismiss) private var dismiss

    init(mode: ShareWeekViewModel.Mode) {
        _viewModel = State(initialValue: ShareWeekViewModel(mode: mode))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sectionTop) {
            HStack {
                Text(viewModel.sheetTitle)
                    .textStyle(Typography.navTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                GlassIconButton(icon: .close, accessibilityLabel: "Close") { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.sectionTop) {
                    if viewModel.isWeek { ShareWeekOptions(viewModel: viewModel) }
                    ShareWeekPreview(card: card)
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.System.error)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Button { isSharing = true } label: {
                Text("Share").frame(maxWidth: .infinity)
            }
            .buttonStyle(.rpPrimary)
            .disabled(card == nil)
        }
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.top, Tokens.Spacing.sectionTop)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tokens.Base.ground)
        .task {
            await viewModel.load()
            redraw()
        }
        .onChange(of: viewModel.which) { redraw() }
        .onChange(of: viewModel.audience) { redraw() }
        .sheet(isPresented: $isSharing) {
            if let card {
                ActivityShareSheet(items: [card] + (ShareCardRules.link.map { [$0] } ?? []))
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func redraw() {
        card = viewModel.render()
    }
}

/// The picture as it will be shared, or a placeholder while it's made.
private struct ShareWeekPreview: View {
    let card: UIImage?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.photo, style: .continuous)
        if let card {
            Image(uiImage: card)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
                .accessibilityLabel("Picture to share")
        } else {
            shape.fill(Tokens.Surface.card)
                .aspectRatio(Tokens.Size.shareCardWidth / Tokens.Size.shareCardHeight, contentMode: .fit)
                .overlay { ProgressView().tint(Tokens.Ink.primary) }
                .accessibilityLabel("Preparing the picture")
        }
    }
}
