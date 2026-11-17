//
//  ReviewSheetView.swift
//  Rowing Pals
//

import PhotosUI
import SwiftUI

/// Screen 4 — session review. Redesign phase F (docs/design/
/// rowing-pals-redesign-handoff-v2.md §2 Screen 05): the big session total,
/// the main-workout label, each piece (photographed pieces are read by OCR;
/// a manual entry types them), a strip of extra photos, the session type
/// (Training or a test, validated), the leaderboards switch, who can see it,
/// a caption, and Post.
///
/// A manual entry (`selfieJPEG == nil`) has no photos to verify, so it stays
/// personal: no test types, no leaderboards switch — and says so.
struct ReviewSheetView: View {
    /// Closes the whole "Post" sheet on a successful post. Not
    /// `@Environment(\.dismiss)` — this view is pushed onto the same
    /// NavigationStack as `CaptureView` underneath it, so its own dismiss
    /// would only pop back to that camera screen instead of closing the
    /// sheet, leaving a stale, already-used capture session behind.
    let onPosted: () -> Void
    @State private var viewModel: ReviewSheetViewModel
    /// "Add photo" → Take photo / Choose from library.
    @State private var isShowingAddPhotoChoice = false
    @State private var isShowingCamera = false
    @State private var isShowingLibrary = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @FocusState private var focusedField: ReviewField?

    private let initialMonitorPhoto: Data?

    /// A photographed session passes both photos; a manual entry passes nil
    /// for both.
    init(selfieJPEG: Data?, isLiveCapture: Bool, initialMonitorPhoto: Data?, linkedWorkout: CoachWorkout? = nil,
         onPosted: @escaping () -> Void) {
        self.initialMonitorPhoto = initialMonitorPhoto
        self.onPosted = onPosted
        _viewModel = State(initialValue: ReviewSheetViewModel(
            selfieJPEG: selfieJPEG, isLiveCapture: isLiveCapture, startsBlank: initialMonitorPhoto == nil, linkedWorkout: linkedWorkout
        ))
    }

    @Environment(\.dismiss) private var dismissScreen

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ReviewTotalCard(totalDistanceM: viewModel.totalDistanceM)

                // "Check" when any number was read from a photo; "Enter" when all were typed.
                ReviewSectionTitle(text: viewModel.segments.contains { $0.photoJPEG != nil } ? "Check the numbers" : "Enter the numbers")
                VStack(spacing: Tokens.Spacing.loose) {
                    ForEach($viewModel.segments) { $segment in
                        SegmentRowView(
                            segment: $segment,
                            focusedField: $focusedField,
                            isLead: viewModel.segments.count > 1 && segment.id == viewModel.leadSegmentID,
                            onRemove: viewModel.segments.count > 1 ? { viewModel.removeSegment(segment.id) } : nil,
                            onNotMonitor: segment.photoJPEG != nil && viewModel.segments.count > 1
                                ? { viewModel.moveSegmentToGallery(segment.id) } : nil
                        )
                    }
                }

                if viewModel.isProcessingPhoto {
                    HStack(spacing: Tokens.Spacing.gap) {
                        ProgressView()
                        Text("Reading photo…")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Spacing.loose)
                }

                if viewModel.isManual {
                    // A manual entry adds a blank piece to type into.
                    Button {
                        viewModel.addManualSegment()
                    } label: {
                        Label("Add another piece", icon: .plus)
                    }
                    .buttonStyle(.rpGlass)
                    .padding(.top, Tokens.Spacing.loose)
                }

                ReviewSectionTitle(text: "Splits")
                ReviewZonePicker(viewModel: viewModel)
                ReviewEffortPicker(viewModel: viewModel)
                ReviewSplitsSummary(viewModel: viewModel)
                    .padding(.top, Tokens.Spacing.loose)

                ReviewSectionTitle(text: "Caption")
                ReviewCaptionField(viewModel: viewModel)

                ReviewSectionTitle(text: "Trained with")
                ReviewTrainedWithRow(viewModel: viewModel)

                ReviewSectionTitle(text: "Photos")
                ReviewPhotoStrip(viewModel: viewModel)
                // One way to add any photo — camera or library. Each is read: a monitor becomes a
                // piece, anything else an environment photo (docs/design/v2-decisions.md #8–9).
                Button {
                    isShowingAddPhotoChoice = true
                } label: {
                    Text("Add another photo")
                }
                .buttonStyle(.rpGlass)
                .disabled(viewModel.isProcessingPhoto)

                ReviewSessionTypeSection(viewModel: viewModel)
                    .padding(.vertical, Tokens.Spacing.loose)

                if viewModel.isManual {
                    Text("Manual sessions count toward your own totals and streak, but never appear on leaderboards or set test results — the numbers can't be checked against a monitor photo.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .guidance()
                } else {
                    ReviewLeaderboardToggle(viewModel: viewModel)
                }

                ReviewErgEventRow(viewModel: viewModel)

                ReviewSectionTitle(text: "Who can see this")
                ReviewVisibilityPicker(viewModel: viewModel)

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.loose)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Review session") { dismissScreen() } }
        .safeAreaInset(edge: .bottom, spacing: 0) { ReviewPostBar(viewModel: viewModel, onPosted: onPosted) }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.loadClubTests() }
        .task { await viewModel.loadOpenEvents() }
        .task {
            guard viewModel.segments.isEmpty, let initialMonitorPhoto else { return }
            await viewModel.addSegment(from: initialMonitorPhoto)
            focusFirstLowConfidenceField()
        }
        .confirmationDialog("Add photo", isPresented: $isShowingAddPhotoChoice) {
            Button("Take photo") { isShowingCamera = true }
            Button("Choose from library") { isShowingLibrary = true }
        } message: {
            Text("A photo of the erg monitor is read and added as a piece. Any other photo is added to the post's photos.")
                .guidance()
        }
        .sheet(isPresented: $isShowingCamera) {
            NavigationStack {
                MonitorPhotoCaptureView { data in
                    Task { await viewModel.addPhoto(data) }
                }
            }
        }
        .photosPicker(isPresented: $isShowingLibrary, selection: $pickedItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPickedPhotos(items) }
        }
    }

    // MARK: - Photos from the library

    /// Loads the picker's selections one by one (each is read in turn),
    /// shrinking them first — a library photo can be 10+ MB. Clears the
    /// picker so the same photo can be chosen again after removing it.
    @MainActor
    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let jpeg = await Self.downscaledJPEG(from: data)
            else { continue }
            await viewModel.addPhoto(jpeg)
        }
        pickedItems = []
    }

    /// JPEG at 80% quality, longest side capped at 1600 pixels, shrunk off the main actor.
    private static func downscaledJPEG(from data: Data) async -> Data? {
        await PhotoDownscaler.jpeg(from: data, maxPixelSide: 1600, quality: 0.8,
                                   screenFormat: true, reencodesSmallPhotos: true)
    }

    /// "Pre-focused for checking" (design brief) — lands the keyboard on the
    /// first field the OCR pass wasn't confident about, if any. The average
    /// is derived, so it is never a candidate.
    private func focusFirstLowConfidenceField() {
        guard
            let segment = viewModel.segments.first,
            let field = [DraftSegment.Field.distance, .time, .rate]
                .first(where: { segment.lowConfidenceFields.contains($0) })
        else { return }
        focusedField = .field(segmentId: segment.id, field: field)
    }
}

#Preview {
    NavigationStack {
        ReviewSheetView(selfieJPEG: Data(), isLiveCapture: true, initialMonitorPhoto: Data(), onPosted: {})
    }
}
