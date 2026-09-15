//
//  ReviewSheetView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 4 — session review. Recomputes the session total from segments
/// live, runs OCR on every photo (the first at appear, more via "+ Add
/// another photo"), shows the test-detection prompt when the Main segment
/// matches a standard distance, and writes the real `sessions` +
/// `segments` (+ `test_results`, on Yes) rows on Post.
struct ReviewSheetView: View {
    /// Closes the whole "Post" sheet on a successful post. Not
    /// `@Environment(\.dismiss)` — this view is pushed onto the same
    /// NavigationStack as `CaptureView` underneath it, so its own dismiss
    /// would only pop back to that camera screen instead of closing the
    /// sheet, leaving a stale, already-used capture session behind.
    let onPosted: () -> Void
    @State private var viewModel: ReviewSheetViewModel
    @State private var isShowingAddPhoto = false
    @FocusState private var focusedField: ReviewField?

    private let initialMonitorPhoto: Data

    init(selfieJPEG: Data, initialMonitorPhoto: Data, onPosted: @escaping () -> Void) {
        self.initialMonitorPhoto = initialMonitorPhoto
        self.onPosted = onPosted
        _viewModel = State(initialValue: ReviewSheetViewModel(selfieJPEG: selfieJPEG))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Check your numbers")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)

                totalCard

                VStack(spacing: 8) {
                    ForEach($viewModel.segments) { $segment in
                        SegmentRowView(segment: $segment, focusedField: $focusedField)
                    }
                }

                if viewModel.isProcessingPhoto {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading monitor…")
                            .textStyle(Typography.bodySecondary)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Button {
                    isShowingAddPhoto = true
                } label: {
                    Text("+ Add another photo")
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Tokens.Ink.primary.opacity(0.05))
                        }
                }
                .buttonStyle(.plain)

                if viewModel.showsTestPrompt, let test = viewModel.detectedTest {
                    testDetectedBanner(test)
                }

                if let postError = viewModel.postError {
                    Text(postError)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Accent.live)
                }

                HStack(spacing: 10) {
                    TextField("Add a caption…", text: $viewModel.caption)
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .glassSurface(cornerRadius: 18)

                    postButton
                }
            }
            .padding(16)
        }
        .background(Tokens.Base.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel.segments.isEmpty else { return }
            await viewModel.addSegment(from: initialMonitorPhoto)
            focusFirstLowConfidenceField()
        }
        .sheet(isPresented: $isShowingAddPhoto) {
            NavigationStack {
                MonitorPhotoCaptureView { data in
                    Task { await viewModel.addSegment(from: data) }
                }
            }
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION TOTAL")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(viewModel.totalDistanceM.formattedWithGrouping)
                    .font(.system(size: 31, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("m")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            HStack(spacing: 24) {
                StatColumn(label: "TIME", value: viewModel.totalTimeMs.formattedDurationMs)
                StatColumn(label: "AVG /500M", value: viewModel.avgSplitMs?.formattedDurationMs ?? "—")
                StatColumn(label: "RATE", value: viewModel.avgRate.map { "r\(Int($0.rounded()))" } ?? "—")
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
    }

    /// "Nothing enters the rankings without this tap" (design brief) — Yes
    /// only records the decision locally; the actual `test_results` row is
    /// written in `post()`, since it needs the session and segment rows to
    /// exist first.
    private func testDetectedBanner(_ test: StandardTest) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This looks like a \(test.label) test.")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Add it to the \(test.label) leaderboard?")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Button {
                viewModel.decideTest(accepted: true)
            } label: {
                Text("Yes")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Base.dark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tokens.Accent.signal)
                    }
            }
            Button {
                viewModel.decideTest(accepted: false)
            } label: {
                Text("No")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tokens.Ink.primary.opacity(0.1))
                    }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Accent.signal.opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Tokens.Accent.signal.opacity(0.35), lineWidth: 1)
        }
        .buttonStyle(.plain)
    }

    private var postButton: some View {
        Button {
            Task {
                if await viewModel.post() { onPosted() }
            }
        } label: {
            Group {
                if viewModel.isPosting {
                    ProgressView().tint(Tokens.Base.dark)
                } else {
                    Text("Post")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Tokens.Base.dark)
                }
            }
            .frame(width: 104, height: 52)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Tokens.Accent.signal.opacity(viewModel.canPost ? 1 : 0.4))
            }
        }
        .disabled(!viewModel.canPost)
    }

    /// "Pre-focused for checking" (design brief) — lands the keyboard on the
    /// first field the OCR pass wasn't confident about, if any.
    private func focusFirstLowConfidenceField() {
        guard
            let segment = viewModel.segments.first,
            let field = [DraftSegment.Field.distance, .time, .split, .rate]
                .first(where: { segment.lowConfidenceFields.contains($0) })
        else { return }
        focusedField = .field(segmentId: segment.id, field: field)
    }
}

#Preview {
    NavigationStack {
        ReviewSheetView(selfieJPEG: Data(), initialMonitorPhoto: Data(), onPosted: {})
    }
}
