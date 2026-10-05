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
    /// Closes the whole Log modal after posting.
    let onPosted: () -> Void
    /// Closes the Log modal without posting (the back button).
    let onClose: () -> Void

    @State private var viewModel = CaptureViewModel()
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

    private struct InitialCapture: Hashable {
        let id = UUID()
        let rearJPEG: Data
        let frontJPEG: Data
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
                Text("Front + rear · No time limit")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.screen)

            Button {
                isManualEntry = true
            } label: {
                Label("Enter session manually", systemImage: "plus")
            }
            .buttonStyle(.rpGlass)
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.gap)

            controls
                .padding(.top, 12)
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, 16)
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .navigationDestination(item: $initialCapture) { capture in
            ReviewSheetView(selfieJPEG: capture.frontJPEG, initialMonitorPhoto: capture.rearJPEG, onPosted: onPosted)
        }
        .navigationDestination(item: $libraryStart) { start in
            ReviewSheetView(selfieJPEG: nil, initialMonitorPhoto: start.jpeg, onPosted: onPosted)
        }
        .navigationDestination(isPresented: $isManualEntry) {
            ReviewSheetView(selfieJPEG: nil, initialMonitorPhoto: nil, onPosted: onPosted)
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

                insetPreview
                    .frame(width: geometry.size.width * 0.27, height: geometry.size.height * 0.37)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous)
                            .strokeBorder(Tokens.Surface.card, lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.33), radius: 7, y: 5)
                    .padding(10)
                    .onLongPressGesture { isShowingCornerPicker = true }
                    .accessibilityLabel("Front camera preview")
                    .accessibilityHint("Press and hold to move it to another corner")
                    .accessibilityAction(named: "Move preview") { isShowingCornerPicker = true }

                if case .failed(let message) = viewModel.phase {
                    failureOverlay(message)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .frame(maxHeight: 530)
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

    @ViewBuilder
    private var insetPreview: some View {
        let layer = isFrontPrimary ? viewModel.rearPreviewLayer : viewModel.frontPreviewLayer
        if let layer {
            CameraPreviewView(previewLayer: layer)
        } else {
            PhotoPlaceholder(cornerRadius: Tokens.Radius.photoInset, caption: isFrontPrimary ? "REAR" : "FRONT")
        }
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
                Image(systemName: "arrow.left.arrow.right")
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(width: 48, height: 48)
                    .glassSurface(in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel("Flip camera")
            .frame(maxWidth: .infinity)

            shutterSlot
                .frame(maxWidth: .infinity)

            PhotosPicker(selection: $libraryItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
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
                    if let (rear, front) = await viewModel.captureInitialPair() {
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
