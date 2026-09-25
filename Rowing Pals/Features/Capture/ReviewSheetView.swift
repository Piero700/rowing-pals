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
    /// Redesign phase B — per-device display preferences, not synced to
    /// the profile. See DesignSystem/PaceDisplay.swift.
    /// The session-total card is a read-only recap (not an editable
    /// field), so it's safe to make unit-aware.
    @AppStorage(PaceDisplay.storageKey) private var paceDisplay: PaceDisplay = .split

    private let initialMonitorPhoto: Data?

    /// A photographed session passes both photos; a manual entry passes nil
    /// for both.
    init(selfieJPEG: Data?, initialMonitorPhoto: Data?, onPosted: @escaping () -> Void) {
        self.initialMonitorPhoto = initialMonitorPhoto
        self.onPosted = onPosted
        _viewModel = State(initialValue: ReviewSheetViewModel(selfieJPEG: selfieJPEG))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.isManual ? "Enter your session" : "Check your numbers")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)

                totalCard
                workoutLabelPicker

                VStack(spacing: 8) {
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
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading photo…")
                            .textStyle(Typography.bodySecondary)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                if viewModel.isManual {
                    addPieceButton
                }
                addPhotoButton

                environmentPhotoStrip

                sessionTypeSection

                if viewModel.isManual {
                    Text("Manual sessions count toward your own totals and streak, but never appear on leaderboards or set test results — the numbers can't be checked against a monitor photo.")
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                } else {
                    leaderboardToggle
                }

                visibilityPicker

                if let blocker = viewModel.postBlocker {
                    Text(blocker)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                if let postError = viewModel.postError {
                    Text(postError)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.System.error)
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
        .dismissesKeyboardOnTap()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Main workout label

    /// "Main workout label" — the badge on the main split. A test replaces
    /// it with the test's own name, so the picker steps aside.
    @ViewBuilder
    private var workoutLabelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MAIN WORKOUT LABEL")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            if let testLabel = viewModel.sessionKind.testLabel {
                menuRow(text: testLabel)
                    .opacity(0.6)
                Text("Set by the session type below.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            } else {
                Menu {
                    Picker("Main workout label", selection: $viewModel.workoutLabel) {
                        ForEach(WorkoutLabel.allCases) { label in
                            Text(label.rawValue).tag(label)
                        }
                    }
                } label: {
                    menuRow(text: viewModel.workoutLabel.rawValue)
                }
            }
        }
    }

    /// The closed look of a dropdown: value on the left, chevrons on the right.
    private func menuRow(text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(Tokens.Ink.primary)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.07))
        }
    }

    // MARK: - Pieces and photos

    /// A manual entry adds a blank piece to type into.
    private var addPieceButton: some View {
        Button {
            viewModel.addManualSegment()
        } label: {
            Text("+ Add another piece")
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Tokens.Ink.primary.opacity(0.05))
                }
        }
        .buttonStyle(.plain)
    }

    /// One way to add any photo — camera or library. Each is read: a monitor
    /// becomes a piece, anything else an environment photo
    /// (docs/design/v2-decisions.md #8–9).
    private var addPhotoButton: some View {
        Button {
            isShowingAddPhotoChoice = true
        } label: {
            Label("Add photo", systemImage: "camera")
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Accent.brand)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Tokens.Ink.primary.opacity(0.05))
                }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessingPhoto)
    }

    /// Environment photos — no monitor found. Each can be removed, or turned
    /// into a piece if the guess was wrong.
    @ViewBuilder
    private var environmentPhotoStrip: some View {
        if !viewModel.galleryPhotos.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("PHOTOS")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.galleryPhotos) { photo in
                            galleryThumbnail(photo)
                        }
                    }
                }
                Text("Press and hold a photo if it's actually a monitor photo.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
    }

    private func galleryThumbnail(_ photo: ReviewSheetViewModel.GalleryPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: photo.jpeg) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contextMenu {
                        Button {
                            viewModel.readGalleryPhotoAsMonitor(photo.id)
                        } label: {
                            Label("Read as monitor photo", systemImage: "text.viewfinder")
                        }
                        Button(role: .destructive) {
                            viewModel.removeGalleryPhoto(photo.id)
                        } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
            }
            Button {
                viewModel.removeGalleryPhoto(photo.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    // 44-pt tap area around the small visible circle.
                    .frame(width: 44, height: 44, alignment: .topTrailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo")
        }
    }

    /// Loads the picker's selections one by one (each is read in turn),
    /// shrinking them first — a library photo can be 10+ MB. Clears the
    /// picker so the same photo can be chosen again after removing it.
    @MainActor
    private func loadPickedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let jpeg = Self.downscaledJPEG(from: data)
            else { continue }
            await viewModel.addPhoto(jpeg)
        }
        pickedItems = []
    }

    /// JPEG at 80% quality, longest side capped at 1600 pixels.
    private static func downscaledJPEG(from data: Data, maxSide: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image.jpegData(compressionQuality: 0.8) }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Session type

    /// "Session type": Training, or one of the standard tests. Choosing a
    /// test is what records a test result — nothing enters the test rankings
    /// without this choice. The distance must match the test exactly.
    private var sessionTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.showsTestPrompt, let test = viewModel.detectedTest {
                testDetectedBanner(test)
            }

            if !viewModel.isManual {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SESSION TYPE")
                        .textStyle(Typography.label)
                        .foregroundStyle(Tokens.Ink.secondary)
                    Menu {
                        Picker("Session type", selection: $viewModel.sessionKind) {
                            ForEach(viewModel.availableKinds) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                    } label: {
                        menuRow(text: viewModel.sessionKind.label)
                    }
                    if let problem = viewModel.sessionKindProblem {
                        Text(problem)
                            .textStyle(Typography.bodySecondary)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
            }
        }
    }

    /// "Include on leaderboards" — whether this session counts toward your
    /// volume on the leaderboards. Off still counts it in your own profile
    /// and streak.
    private var leaderboardToggle: some View {
        Toggle(isOn: $viewModel.includeOnLeaderboards) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Include on leaderboards")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Include this session in your volume totals.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .tint(Tokens.Accent.success)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.05))
        }
    }

    /// Who can see this post — a new choice at post time, added after
    /// task 18. Defaults to Everyone (`PostVisibility`) — club and
    /// followers combined, the widest of the three.
    private var visibilityPicker: some View {
        let selection = Binding<Int>(
            get: { PostVisibility.allCases.firstIndex(of: viewModel.visibility) ?? 0 },
            set: { viewModel.visibility = PostVisibility.allCases[$0] }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text("WHO CAN SEE THIS")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            PillSegmentedControl(options: PostVisibility.allCases.map(\.label), selection: selection)
        }
    }

    /// "AVG /500M" only means something for a split value — once the
    /// preference is watts, the label has to stop implying a distance unit.
    private var avgSplitLabel: String {
        paceDisplay == .split ? "AVG /500M" : "AVG WATTS"
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION TOTAL")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(viewModel.totalDistanceM > 0 ? viewModel.totalDistanceM.formattedMetres : "—")
                    .font(.system(size: 31, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
            }
            HStack(spacing: 24) {
                StatColumn(label: "TIME", value: viewModel.totalTimeMs > 0 ? viewModel.totalTimeMs.formattedDurationMs : "—")
                StatColumn(label: avgSplitLabel, value: viewModel.avgSplitMs?.formattedPace(display: paceDisplay) ?? "—")
                StatColumn(label: "RATE", value: viewModel.avgRate.map { "r\(Int($0.rounded()))" } ?? "—")
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
    }

    /// "Nothing enters the rankings without this choice" (design brief) —
    /// Yes only picks the test in the Session type dropdown; the actual
    /// `test_results` row is written in `post()`, since it needs the session
    /// and segment rows to exist first.
    private func testDetectedBanner(_ test: StandardTest) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This looks like a \(test.label) test.")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Post it as a \(test.label) test and add it to the leaderboard?")
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
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tokens.Accent.brand)
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
                .fill(Tokens.Accent.brand.opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Tokens.Accent.brand.opacity(0.35), lineWidth: 1)
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
                    .fill(Tokens.Accent.brand.opacity(viewModel.canPost ? 1 : 0.4))
            }
        }
        .disabled(!viewModel.canPost)
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
        ReviewSheetView(selfieJPEG: Data(), initialMonitorPhoto: Data(), onPosted: {})
    }
}
