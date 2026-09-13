//
//  MonitorPhotoCaptureView.swift
//  Rowing Pals
//

import SwiftUI

/// A lightweight rear-camera-only capture screen for the review sheet's
/// "+ Add another photo" — a session can have several monitor photos, but
/// only one selfie, already taken by `CaptureView`. Presented as its own
/// sheet rather than reusing `CaptureView`, so re-shooting a split doesn't
/// also ask for a redundant second selfie.
struct MonitorPhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CaptureViewModel(rearOnly: true)
    let onCaptured: (Data) -> Void

    var body: some View {
        ZStack {
            cameraLayer
            VStack {
                Spacer()
                statusView
                    .padding(.bottom, 60)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if let layer = viewModel.rearPreviewLayer {
            CameraPreviewView(previewLayer: layer)
                .ignoresSafeArea()
        } else if case .failed = viewModel.phase {
            Tokens.Base.dark.ignoresSafeArea()
        } else {
            PhotoPlaceholder(cornerRadius: 0, caption: "STARTING CAMERA…")
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.phase {
        case .ready:
            shutterButton
        case .capturingRear, .done:
            ProgressView().tint(Tokens.Ink.primary)
        case .failed(let message):
            VStack(spacing: 10) {
                Text(message)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Accent.live)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Try again") {
                    if viewModel.rearPreviewLayer == nil {
                        viewModel.start()
                    } else {
                        viewModel.phase = .ready
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Ink.primary)
            }
        case .configuring, .capturingFront:
            EmptyView()
        }
    }

    private var shutterButton: some View {
        Button {
            Task {
                if let data = await viewModel.captureMonitorPhoto() {
                    onCaptured(data)
                    dismiss()
                }
            }
        } label: {
            Circle()
                .fill(Tokens.Ink.primary.opacity(0.1))
                .frame(width: 88, height: 88)
                .overlay {
                    Circle().fill(Tokens.Base.light).frame(width: 68, height: 68)
                }
        }
    }
}

#Preview {
    NavigationStack {
        MonitorPhotoCaptureView(onCaptured: { _ in })
    }
}
