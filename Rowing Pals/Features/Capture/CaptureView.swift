//
//  CaptureView.swift
//  Rowing Pals
//

import AVFoundation
import PhotosUI
import SwiftUI

/// Screen 04 — Log workout, to v3 (`docs/design/v3/RP Screen.dc.html` §04): glass back button,
/// "Log workout", Help; the dual-camera frame (radius 22) with the front camera inset (27 % ×
/// 37 %, top-right by default); "Front + rear · No time limit"; "Enter session manually"; and a
/// flip / shutter / library row. Simultaneous capture on multi-cam devices, sequential rear then
/// front elsewhere. Nothing is uploaded until the rower confirms the numbers on Review.
///
/// A photo chosen from the library has no live selfie, so — like manual entry — the session is
/// unverified and stays personal (decision 2026-09-24); the photo is still read.
struct CaptureView: View {
    /// The workout chosen on its Feed card ("Log it"): Log offers only that one (decision 57).
    var workoutId: UUID?
    /// Closes the whole Log modal after posting.
    let onPosted: () -> Void
    /// Closes the Log modal without posting (the back button).
    let onClose: () -> Void

    /// Rear-only while the selfie is off, so the front camera isn't on at all.
    @State private var viewModel: CaptureViewModel
    /// The selfie (the front camera, the rower's face) for this session — starts from Settings →
    /// Logging and can be switched here (decision 98). Off: only the monitor photo is taken.
    @State private var takesSelfie: Bool
    @State private var initialCapture: InitialCapture?
    @State private var libraryStart: LibraryStart?
    /// Which corner the front preview sits in — user-configurable (phase D); press and hold the
    /// inset to change it.
    @AppStorage(InsetCorner.storageKey) private var insetCorner: InsetCorner = .defaultCorner
    @State private var isShowingCornerPicker = false
    @State private var isManualEntry = false
    @State private var isShowingHelp = false
    /// "Flip camera": which camera fills the frame. The rear photo is always the monitor.
    @State private var isFrontPrimary = false
    @State private var libraryItem: PhotosPickerItem?
    /// The workouts the rower's coaches set for today that they haven't posted for, and which one
    /// this session is for (RowerLogCoaching, decisions 39, 57) — just the one chosen on the Feed,
    /// if Log was opened from its card. Linking is on by default.
    @State private var todaysWorkouts: [TodaysWorkout] = []
    @State private var chosenWorkout = 0
    @State private var linksWorkout = true

    /// The workout the session will be linked to, if any.
    private var linkedWorkout: CoachWorkout? {
        guard linksWorkout, todaysWorkouts.indices.contains(chosenWorkout) else { return nil }
        return todaysWorkouts[chosenWorkout].workout
    }

    init(workoutId: UUID? = nil, onPosted: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.workoutId = workoutId
        self.onPosted = onPosted
        self.onClose = onClose
        let selfie = UserDefaults.standard.object(forKey: SelfieDefault.storageKey) as? Bool ?? true
        _takesSelfie = State(initialValue: selfie)
        _viewModel = State(initialValue: CaptureViewModel(rearOnly: !selfie))
    }

    private struct InitialCapture: Hashable {
        let id = UUID()
        let rearJPEG: Data
        /// Nil when the selfie was switched off for this session.
        let frontJPEG: Data?
    }

    private struct LibraryStart: Hashable {
        let id = UUID()
        let jpeg: Data
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: Tokens.Spacing.gap) {
                cameraFrame
                selfieRow
            }
            .padding(.horizontal, Tokens.Spacing.screen)

            Button {
                isManualEntry = true
            } label: {
                Label("Enter session manually", icon: .plus)
            }
            .buttonStyle(.rpGlass)
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.gap)

            controls
                .padding(.top, Tokens.Spacing.loose)
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, 16)
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
        .task {
            let today = await WorkoutService.today()
            // From a workout's card: that workout only, so there's nothing else to choose.
            todaysWorkouts = workoutId.map { id in today.filter { $0.id == id } } ?? today
        }
        .onDisappear { viewModel.stop() }
        .navigationDestination(item: $initialCapture) { capture in
            ReviewSheetView(selfieJPEG: capture.frontJPEG, isLiveCapture: true, initialMonitorPhoto: capture.rearJPEG,
                            linkedWorkout: linkedWorkout, onPosted: onPosted)
        }
        .navigationDestination(item: $libraryStart) { start in
            ReviewSheetView(selfieJPEG: nil, isLiveCapture: false, initialMonitorPhoto: start.jpeg,
                            linkedWorkout: linkedWorkout, onPosted: onPosted)
        }
        .navigationDestination(isPresented: $isManualEntry) {
            ReviewSheetView(selfieJPEG: nil, isLiveCapture: false, initialMonitorPhoto: nil,
                            linkedWorkout: linkedWorkout, onPosted: onPosted)
        }
        .sheet(isPresented: $isShowingCornerPicker) {
            InsetCornerPickerView(selection: $insetCorner)
        }
        .sheet(isPresented: $isShowingHelp) {
            helpSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task { await startFromLibrary(item) }
        }
    }

    // MARK: - Header

    /// The shared pushed-screen header: back, centred "Log workout", and Help on the right.
    private var header: some View {
        ScreenHeader(title: "Log workout", onBack: onClose) {
            Button("Help") { isShowingHelp = true }
                .buttonStyle(.rpText)
        }
    }

    // MARK: - Camera

    private var cameraFrame: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.photo, style: .continuous)
        return GeometryReader { geometry in
            ZStack(alignment: insetCorner.alignment) {
                mainPreview
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(shape)

                if takesSelfie {
                    insetPreview
                        .frame(width: geometry.size.width * Tokens.Size.cameraInsetShare,
                               height: geometry.size.height * Tokens.Size.cameraInsetShare)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous)
                                .strokeBorder(Tokens.Surface.card, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.33), radius: 7, y: 5)
                        .padding(Tokens.Spacing.gap)
                        .onLongPressGesture { isShowingCornerPicker = true }
                        .accessibilityLabel("Front camera preview")
                        .accessibilityHint("Press and hold to move it to another corner")
                        .accessibilityAction(named: "Move preview") { isShowingCornerPicker = true }
                }

                if todaysWorkouts.indices.contains(chosenWorkout) {
                    workoutPanel(todaysWorkouts[chosenWorkout])
                        .padding(Tokens.Spacing.gap)
                        .frame(width: geometry.size.width, height: geometry.size.height,
                               alignment: insetCorner.isBottom ? .top : .bottom)
                }

                if case .failed(let message) = viewModel.phase {
                    failureOverlay(message)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        // 3:4 upright, the shape the iPhone saves: what you see is the photo (decision 55).
        .aspectRatio(Tokens.Size.cameraAspect, contentMode: .fit)
    }

    /// The rear camera by default; the front camera after "Flip camera".
    @ViewBuilder
    private var mainPreview: some View {
        let layer = isFrontPrimary ? viewModel.frontPreviewLayer : viewModel.rearPreviewLayer
        if let layer {
            CameraPreviewView(previewLayer: layer)
        } else {
            PhotoPlaceholder(cornerRadius: Tokens.Radius.photo, caption: viewModel.phase == .configuring ? "STARTING CAMERA…" : "REAR CAMERA")
        }
    }

    /// "Front + rear" or "Monitor only", and the selfie switch for this session (decision 98).
    private var selfieRow: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            Text(takesSelfie ? "Front + rear · No time limit" : "Monitor only · No time limit")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
            Spacer(minLength: 0)
            Text("Selfie")
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.primary)
            Toggle("Take a selfie with this session", isOn: Binding(
                get: { takesSelfie },
                set: { setTakesSelfie($0) }
            ))
            .labelsHidden()
            .tint(Tokens.Accent.brand)
            .disabled(viewModel.phase == .capturingRear || viewModel.phase == .capturingFront)
        }
        .padding(.horizontal, 2)
    }

    /// Restarts the camera with or without the front camera, so a session without a selfie never
    /// turns the front camera on.
    private func setTakesSelfie(_ isOn: Bool) {
        guard isOn != takesSelfie else { return }
        takesSelfie = isOn
        if !isOn { isFrontPrimary = false }
        viewModel.stop()
        viewModel = CaptureViewModel(rearOnly: !isOn)
        viewModel.start()
    }

    @ViewBuilder
    private var insetPreview: some View {
        let layer = isFrontPrimary ? viewModel.rearPreviewLayer : viewModel.frontPreviewLayer
        if let layer {
            CameraPreviewView(previewLayer: layer)
        } else {
            PhotoPlaceholder(cornerRadius: Tokens.Radius.photoInset, caption: isFrontPrimary ? "REAR" : "FRONT")
        }
    }

    /// RowerLogCoaching: today's workout over the camera, and "Link this session" (on by default).
    /// With more than one workout today, tapping the title chooses which.
    private func workoutPanel(_ today: TodaysWorkout) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            Menu {
                ForEach(Array(todaysWorkouts.enumerated()), id: \.element.id) { index, item in
                    Button(item.workout.title) { chosenWorkout = index }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today’s workout")
                        .textStyle(Typography.kicker)
                        .foregroundStyle(Tokens.Accent.brand)
                    HStack(spacing: 4) {
                        Text("\(today.workout.title) · \(today.zoneText)")
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                        if todaysWorkouts.count > 1 {
                            RPIconView(icon: .chevronUpDown, size: Tokens.Icon.small)
                                .textStyle(Typography.pill)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                    }
                    if let detail = panelDetail(today) {
                        Text(detail)
                            .textStyle(Typography.meta)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(todaysWorkouts.count < 2)
            HStack(spacing: Tokens.Spacing.loose) {
                Text("Link this session")
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                Toggle("Link this session to today’s workout", isOn: $linksWorkout)
                    .labelsHidden()
                    .tint(Tokens.Accent.brand)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Tokens.Spacing.loose)
        .glassSurface(in: RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous))
    }

    /// "Rate 18–20 · split 2:05".
    private func panelDetail(_ today: TodaysWorkout) -> String? {
        var parts: [String] = []
        if let rate = today.rateText { parts.append("Rate \(rate)") }
        if let split = today.targetSplitMs { parts.append("split \(WorkoutRules.splitText(split))") }
        guard !parts.isEmpty else { return nil }
        let text = parts.joined(separator: " · ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func failureOverlay(_ message: String) -> some View {
        VStack(spacing: Tokens.Spacing.gap) {
            Text(message)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .multilineTextAlignment(.center)
            Button("Try again") {
                // A session that already has a preview only failed a capture; one that never
                // configured (e.g. permission denied) needs a real restart.
                if viewModel.rearPreviewLayer == nil {
                    viewModel.start()
                } else {
                    viewModel.phase = .ready
                }
            }
            .buttonStyle(.rpGlassCompact)
        }
        .padding(20)
        .background(Tokens.Base.ground.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photo, style: .continuous))
    }

    // MARK: - Controls

    /// Flip (48 glass) · shutter (76 white, 6 pt raised ring, 2 pt white outer) · library (48 glass).
    private var controls: some View {
        HStack {
            Button {
                withAnimation(.snappy) { isFrontPrimary.toggle() }
            } label: {
                RPIconView(icon: .flipCamera)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: 48, height: 48)
                    .glassSurface(in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel("Flip camera")
            // Nothing to flip to without the selfie.
            .opacity(takesSelfie ? 1 : 0)
            .disabled(!takesSelfie)
            .frame(maxWidth: .infinity)

            shutterSlot
                .frame(maxWidth: .infinity)

            PhotosPicker(selection: $libraryItem, matching: .images) {
                RPIconView(icon: .photo)
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: 48, height: 48)
                    .glassSurface(in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel("Choose from library")
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var shutterSlot: some View {
        switch viewModel.phase {
        case .capturingRear, .capturingFront, .done:
            ProgressView()
                .tint(Tokens.Ink.primary)
                .frame(width: 76, height: 76)
        default:
            Button {
                Task {
                    if !takesSelfie {
                        if let rear = await viewModel.captureMonitorPhoto() {
                            viewModel.stop()
                            initialCapture = InitialCapture(rearJPEG: rear, frontJPEG: nil)
                        }
                    } else if let (rear, front) = await viewModel.captureInitialPair() {
                        // Release the camera before Review can start another session for
                        // "Add photo" — this view stays on the stack, so onDisappear isn't
                        // a reliable moment.
                        viewModel.stop()
                        initialCapture = InitialCapture(rearJPEG: rear, frontJPEG: front)
                    }
                }
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)
                    .padding(6)
                    .background(Circle().fill(Tokens.Surface.raised))
                    .padding(2)
                    .background(Circle().fill(Color.white))
                    .contentShape(Circle())
            }
            .buttonStyle(IconPressStyle())
            .disabled(viewModel.phase != .ready)
            .accessibilityLabel("Take photo")
        }
    }

    // MARK: - Library

    @MainActor
    private func startFromLibrary(_ item: PhotosPickerItem) async {
        defer { libraryItem = nil }
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return }
        viewModel.stop()
        libraryStart = LibraryStart(jpeg: jpeg)
    }

    // MARK: - Help

    private var helpSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.loose) {
                Text("Logging a workout")
                    .textStyle(Typography.navTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                helpItem("One tap, two photos", "The shutter takes the monitor with the back camera and you with the front camera at the same moment. There's no time limit.")
                helpItem("No selfie", "Turn Selfie off under the camera to take just the monitor photo this time. Settings › Logging sets whether it starts on or off. The session still counts on leaderboards.")
                helpItem("Photograph the right screen", "On a Concept2 PM5, open Menu › Memory › View Detail for the piece. The app reads the table on that screen: time, metres, /500m and rate.")
                helpItem("Keep it sharp", "Fill the frame with the screen, hold still, and avoid glare from lights above.")
                helpItem("Several pieces", "On the next screen, Add photo takes or chooses more monitor photos — each becomes a piece and its metres are added to the total.")
                helpItem("No photo?", "Enter session manually, or choose a monitor photo from your library. Without a live photo the session counts for your own totals and streak but not on leaderboards.")
                helpItem("Move the selfie preview", "Press and hold the small preview to put it in another corner.")
            }
            .padding(20)
        }
        .background(Tokens.Base.ground)
    }

    private func helpItem(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .textStyle(Typography.name)
                .foregroundStyle(Tokens.Ink.primary)
            Text(body)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }
}
