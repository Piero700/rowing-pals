//
//  SecondPhotoCaptureView.swift
//  Rowing Pals
//

import SwiftUI

/// Log's second step in One at a time (decision 103): the monitor photo is already taken and sits
/// small in the corner, and the rower takes a second photo whenever they're ready. It opens on the
/// back camera for their surroundings; flip turns to the front camera for their face. Skip posts
/// the monitor photo alone. Swiping back returns to Log to retake the monitor photo.
///
/// The monitor photo is held in memory until the post goes, so there's no time limit while the
/// app stays open, and closing the app loses the draft.
struct SecondPhotoCaptureView: View {
    let monitorJPEG: Data
    let linkedWorkout: CoachWorkout?
    let onPosted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(InsetCorner.storageKey) private var insetCorner: InsetCorner = .defaultCorner
    /// One camera at a time, so its session is the rear-only one, which can flip.
    @State private var viewModel = CaptureViewModel(rearOnly: true)
    @State private var review: ReviewStart?

    private struct ReviewStart: Hashable {
        let id = UUID()
        /// Nil after Skip.
        let secondJPEG: Data?
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Second photo", onBack: { dismiss() }) {
                Button("Skip") { goToReview(with: nil) }
                    .buttonStyle(.rpText)
            }

            VStack(spacing: Tokens.Spacing.gap) {
                cameraFrame
                Text(viewModel.isFacingFront ? "Now your face · No time limit" : "Now your surroundings · No time limit")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, Tokens.Spacing.screen)

            Spacer(minLength: 0)

            controls
                .padding(.top, Tokens.Spacing.loose)
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, 16)
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .navigationDestination(item: $review) { start in
            // Live whether or not there's a second photo: the monitor photo was taken just now,
            // and that's what counts for leaderboards (decisions 98, 103).
            ReviewSheetView(selfieJPEG: start.secondJPEG, isLiveCapture: true, initialMonitorPhoto: monitorJPEG,
                            linkedWorkout: linkedWorkout, onPosted: onPosted)
        }
    }

    private var cameraFrame: some View {
        GeometryReader { geometry in
            ZStack(alignment: insetCorner.alignment) {
                preview
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photo, style: .continuous))

                monitorThumbnail
                    .frame(width: geometry.size.width * Tokens.Size.cameraInsetShare,
                           height: geometry.size.height * Tokens.Size.cameraInsetShare)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.photoInset, style: .continuous)
                            .strokeBorder(Tokens.Surface.card, lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.33), radius: 7, y: 5)
                    .padding(Tokens.Spacing.gap)
                    .accessibilityLabel("The monitor photo you just took")

                if case .failed(let message) = viewModel.phase {
                    failureOverlay(message)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        // The same 3:4 frame as Log (decision 55).
        .aspectRatio(Tokens.Size.cameraAspect, contentMode: .fit)
    }

    @ViewBuilder
    private var preview: some View {
        if let layer = viewModel.rearPreviewLayer {
            CameraPreviewView(previewLayer: layer)
        } else {
            PhotoPlaceholder(cornerRadius: Tokens.Radius.photo, caption: viewModel.phase == .configuring ? "STARTING CAMERA…" : "CAMERA")
        }
    }

    @ViewBuilder
    private var monitorThumbnail: some View {
        if let image = UIImage(data: monitorJPEG) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            PhotoPlaceholder(cornerRadius: Tokens.Radius.photoInset, caption: "MONITOR")
        }
    }

    private func failureOverlay(_ message: String) -> some View {
        VStack(spacing: Tokens.Spacing.gap) {
            Text(message)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .multilineTextAlignment(.center)
            HStack(spacing: Tokens.Spacing.group) {
                Button("Try again") { viewModel.retry() }
                    .buttonStyle(.rpGlassCompact)
                if viewModel.isPermissionDenied, let settings = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: settings)
                        .textStyle(Typography.detail)
                        .foregroundStyle(Tokens.Accent.brand)
                }
            }
        }
        .padding(20)
        .background(Tokens.Base.ground.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photo, style: .continuous))
    }

    /// Flip · shutter, spaced as on Log; the third slot stays empty because this photo is camera only.
    private var controls: some View {
        HStack {
            Button {
                viewModel.flipCamera()
            } label: {
                CaptureFlipLabel()
            }
            .buttonStyle(IconPressStyle())
            .disabled(viewModel.phase != .ready)
            .accessibilityLabel(viewModel.isFacingFront ? "Switch to the back camera" : "Switch to the front camera")
            .frame(maxWidth: .infinity)

            shutterSlot
                .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 48, height: 48)
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
                    if let photo = await viewModel.captureSinglePhoto() {
                        goToReview(with: photo)
                    }
                }
            } label: {
                CaptureShutterLabel()
            }
            .buttonStyle(IconPressStyle())
            .disabled(viewModel.phase != .ready)
            .accessibilityLabel("Take second photo")
        }
    }

    private func goToReview(with photo: Data?) {
        // Release the camera before Review can start another session for "Add photo".
        viewModel.stop()
        review = ReviewStart(secondJPEG: photo)
    }
}
