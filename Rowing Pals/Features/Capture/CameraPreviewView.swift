//
//  CameraPreviewView.swift
//  Rowing Pals
//

import AVFoundation
import SwiftUI

/// Wraps an `AVCaptureVideoPreviewLayer` for SwiftUI. `UIViewRepresentable`
/// rather than a hand-built pixel-buffer renderer — this is the system's own
/// live preview, not a re-implementation of one.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // `layerClass` above guarantees this, but avoid a force-cast anyway.
            layer as? AVCaptureVideoPreviewLayer ?? AVCaptureVideoPreviewLayer()
        }
    }
}
