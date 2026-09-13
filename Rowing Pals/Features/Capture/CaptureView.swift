//
//  CaptureView.swift
//  Rowing Pals
//

import AVFoundation
import SwiftUI
import Supabase

/// Screen 3 — single rear-camera capture and upload. The front-camera inset
/// stays a static placeholder until task 08 wires up real dual capture via
/// `AVCaptureMultiCamSession`.
struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CaptureViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            cameraLayer

            VStack {
                countdownBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
            }

            PhotoPlaceholder(cornerRadius: 22, caption: "FRONT CAMERA")
                .frame(width: 104, height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 150)
                .padding(.trailing, 16)

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
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if viewModel.phase == .configuring {
            PhotoPlaceholder(cornerRadius: 0, caption: "STARTING CAMERA…")
                .ignoresSafeArea()
        } else if case .failed = viewModel.phase, viewModel.session.inputs.isEmpty {
            // Camera never came up at all (e.g. permission denied) — no
            // point showing a black preview layer underneath. The message
            // itself renders once, from statusView below.
            Tokens.Base.dark.ignoresSafeArea()
        } else {
            CameraPreviewView(session: viewModel.session)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Tokens.Ink.primary.opacity(0.22), lineWidth: 2)
                .frame(width: 289, height: 230)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 210)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.phase {
        case .ready:
            shutterButton
        case .capturing:
            statusLabel("Capturing…")
        case .uploading:
            statusLabel("Uploading…")
        case .done:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Tokens.Accent.signal)
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Base.dark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background {
                        Capsule().fill(Tokens.Accent.signal)
                    }
            }
        case .failed(let message):
            VStack(spacing: 10) {
                Text(message)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Accent.live)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Try again") {
                    // The session itself is fine if it already has an input —
                    // only a capture/upload attempt failed, not camera setup.
                    // A never-configured session (e.g. permission was denied)
                    // needs a real restart, not just flipping the phase.
                    if viewModel.session.inputs.isEmpty {
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
                guard let userId = try? await SupabaseService.shared.auth.session.user.id else { return }
                await viewModel.captureAndUpload(userId: userId)
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
