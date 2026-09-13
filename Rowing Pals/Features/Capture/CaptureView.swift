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
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CaptureViewModel()
    @State private var initialCapture: InitialCapture?

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

            VStack {
                countdownBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
            }

            frontInset

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
            ReviewSheetView(selfieJPEG: capture.frontJPEG, initialMonitorPhoto: capture.rearJPEG)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 150)
        .padding(.trailing, 16)
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
                    .foregroundStyle(Tokens.Accent.live)
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

    private var countdownBanner: some View {
        VStack(spacing: 10) {
            HStack {
                Text("CAPTURE WINDOW OPEN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Tokens.Accent.live)
                Spacer()
                Text("8:42 left")
                    .font(.system(size: 17, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.live)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.Ink.primary.opacity(0.16))
                    Capsule().fill(Tokens.Accent.live).frame(width: geometry.size.width * 0.58)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Tokens.Accent.live.opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Tokens.Accent.live.opacity(0.3), lineWidth: 1)
        }
    }

    private var shutterButton: some View {
        Button {
            Task {
                if let (rear, front) = await viewModel.captureInitialPair() {
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
}

#Preview {
    NavigationStack {
        CaptureView()
    }
}
