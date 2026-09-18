//
//  CaptureView.swift
//  Rowing Pals
//

import AVFoundation
import SwiftUI

/// Screen 3 — dual camera capture. Simultaneous on devices that support
/// `AVCaptureMultiCamSession` (iPhone 11+); sequential rear-then-front
/// elsewhere. On success, pushes straight into the review sheet (task 10) —
/// nothing is uploaded or written to the database until the user confirms
/// the extracted numbers there.
struct CaptureView: View {
    /// Closes the whole "Post" sheet, all the way back to the feed — passed
    /// down from `PostSheetView` (the sheet's actual owner) rather than
    /// resolved locally, and threaded on into `ReviewSheetView` below.
    let onPosted: () -> Void
    @State private var viewModel = CaptureViewModel()
    @State private var initialCapture: InitialCapture?
    /// Which corner the front-camera inset preview sits in — genuinely
    /// user-configurable per the redesign handoff (§3), set via the
    /// corner-picker sheet below. A per-device display preference like
    /// `DistanceUnit`/`PaceDisplay`, so `@AppStorage` rather than a
    /// `profiles` column.
    @AppStorage(InsetCorner.storageKey) private var insetCorner: InsetCorner = .defaultCorner
    @State private var isShowingCornerPicker = false

    /// Identifies one completed rear+front capture, so `.navigationDestination(item:)`
    /// (which requires `Hashable`, not just `Identifiable`) can push the
    /// review sheet as soon as it exists.
    private struct InitialCapture: Hashable {
        let id = UUID()
        let rearJPEG: Data
        let frontJPEG: Data
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            cameraLayer

            frontInset

            cornerPickerButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)

            VStack(spacing: 24) {
                Spacer()
                statusView
                Text("Log a water session instead")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, 6)
            }
            .padding(.bottom, 130)
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .navigationDestination(item: $initialCapture) { capture in
            ReviewSheetView(selfieJPEG: capture.frontJPEG, initialMonitorPhoto: capture.rearJPEG, onPosted: onPosted)
        }
        .sheet(isPresented: $isShowingCornerPicker) {
            InsetCornerPickerView(selection: $insetCorner)
        }
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if viewModel.phase == .configuring {
            PhotoPlaceholder(cornerRadius: 0, caption: "STARTING CAMERA…")
                .ignoresSafeArea()
        } else if case .failed = viewModel.phase, viewModel.rearPreviewLayer == nil {
            // Camera never came up at all (e.g. permission denied) — no
            // point showing a black preview layer underneath. The message
            // itself renders once, from statusView below.
            Tokens.Base.dark.ignoresSafeArea()
        } else if let rearLayer = viewModel.rearPreviewLayer {
            CameraPreviewView(previewLayer: rearLayer)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Tokens.Ink.primary.opacity(0.22), lineWidth: 2)
                .frame(width: 289, height: 230)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 210)
        }
    }

    /// Live once the front camera is actually active — always true once
    /// ready in multi-cam mode; only true once the sequential fallback
    /// reaches its second shot. A static placeholder the rest of the time.
    ///
    /// Position is user-configurable (`insetCorner`, set via the
    /// corner-picker sheet) rather than fixed — a top corner keeps clear of
    /// the monitor-framing guide below it, a bottom corner keeps clear of
    /// the shutter button, so the vertical margin flips with the corner
    /// while the horizontal margin stays the same on either side.
    private var frontInset: some View {
        Group {
            if let frontLayer = viewModel.frontPreviewLayer {
                CameraPreviewView(previewLayer: frontLayer)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                PhotoPlaceholder(cornerRadius: 22, caption: "FRONT CAMERA")
            }
        }
        .frame(width: 104, height: 140)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: insetCorner.alignment)
        .padding(.top, insetCorner.isTop ? 150 : 0)
        .padding(.bottom, insetCorner.isTop ? 0 : 150)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.phase {
        case .ready:
            shutterButton
        case .capturingRear:
            statusLabel(viewModel.isMultiCam ? "Capturing…" : "Capturing rear…")
        case .capturingFront:
            statusLabel("Capturing front…")
        case .done:
            // Transient — `initialCapture` being set fires the
            // `navigationDestination` push into the review sheet on the
            // same runloop tick, so this rarely gets a frame on screen.
            statusLabel("Processing…")
        case .failed(let message):
            VStack(spacing: 10) {
                Text(message)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.System.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Try again") {
                    // The session itself is fine if it already has a rear
                    // preview — only a capture/upload attempt failed, not
                    // camera setup. A never-configured session (e.g.
                    // permission was denied) needs a real restart.
                    if viewModel.rearPreviewLayer == nil {
                        viewModel.start()
                    } else {
                        viewModel.phase = .ready
                    }
                }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
            }
        case .configuring:
            EmptyView()
        }
    }

    private func statusLabel(_ text: String) -> some View {
        VStack(spacing: 10) {
            ProgressView().tint(Tokens.Ink.primary)
            Text(text)
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(Tokens.Ink.secondary)
        }
    }

    private var shutterButton: some View {
        Button {
            Task {
                if let (rear, front) = await viewModel.captureInitialPair() {
                    // Stop here, deterministically, rather than relying on
                    // `.onDisappear` — pushing to ReviewSheetView via
                    // `navigationDestination` keeps this view on the nav
                    // stack (for back-swipe), so `onDisappear` isn't a
                    // reliable place to release the camera before "+ Add
                    // another photo" tries to start a second session.
                    viewModel.stop()
                    initialCapture = InitialCapture(rearJPEG: rear, frontJPEG: front)
                }
            }
        } label: {
            Circle()
                .fill(Tokens.Ink.primary.opacity(0.1))
                .frame(width: 88, height: 88)
                .overlay {
                    Circle()
                        .fill(Tokens.Base.light)
                        .frame(width: 68, height: 68)
                }
        }
    }

    /// Opens the 4-corner inset-position sheet. Pinned top-centre, clear of
    /// every possible inset corner and of the monitor-framing guide below
    /// it — unlike the shutter row, its position can't shift with
    /// `insetCorner` without risking a collision with whichever corner the
    /// inset itself is currently in. Separate control from any "swap
    /// cameras" button (not yet built here) — this changes *where* the
    /// inset sits, not *which* camera is in it.
    private var cornerPickerButton: some View {
        Button {
            isShowingCornerPicker = true
        } label: {
            InsetCornerGlyph(corner: insetCorner, tint: Tokens.Ink.primary)
                .frame(width: 18, height: 14)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: 22)
        .accessibilityLabel("Inset position")
        .accessibilityHint("Choose which corner the front camera preview sits in")
    }
}

#Preview {
    NavigationStack {
        CaptureView(onPosted: {})
    }
}
