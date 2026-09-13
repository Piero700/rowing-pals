//
//  ReviewSheetView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 4 — session review. Recomputes the session total from segments
/// live, runs OCR on every photo (the first at appear, more via "+ Add
/// another photo"), and writes the real `sessions` + `segments` rows on
/// Post. The test-detection prompt in the design brief is task 11's — this
/// screen doesn't fake it.
struct ReviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewSheetViewModel
    @State private var isShowingAddPhoto = false
    @FocusState private var focusedField: ReviewField?

    private let initialMonitorPhoto: Data

    init(selfieJPEG: Data, initialMonitorPhoto: Data) {
        self.initialMonitorPhoto = initialMonitorPhoto
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

    private var postButton: some View {
        Button {
            Task {
                if await viewModel.post() { dismiss() }
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
        ReviewSheetView(selfieJPEG: Data(), initialMonitorPhoto: Data())
    }
}
