//
//  CameraPreviewView.swift
//  Rowing Pals
//

import AVFoundation
import SwiftUI

/// Hosts an already-configured `AVCaptureVideoPreviewLayer` for SwiftUI.
/// `UIViewRepresentable` rather than a hand-built pixel-buffer renderer —
/// this is the system's own live preview, not a re-implementation of one.
///
/// Takes the layer itself, not a session — a single-camera session can build
/// its layer with `AVCaptureVideoPreviewLayer(session:)`, but a multi-cam
/// session's layers are built with `sessionWithNoConnection:` and wired to a
/// specific input port by hand. Either way, by the time this view sees the
/// layer it's already fully connected.
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.host(previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.host(previewLayer)
    }

    final class PreviewUIView: UIView {
        private var hostedLayer: AVCaptureVideoPreviewLayer?

        func host(_ layer: AVCaptureVideoPreviewLayer) {
            guard hostedLayer !== layer else {
                layer.frame = bounds
                return
            }
            hostedLayer?.removeFromSuperlayer()
            layer.videoGravity = .resizeAspectFill
            layer.frame = bounds
            self.layer.addSublayer(layer)
            hostedLayer = layer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            hostedLayer?.frame = bounds
        }
    }
}
