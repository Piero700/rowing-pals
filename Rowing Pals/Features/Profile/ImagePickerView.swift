//
//  ImagePickerView.swift
//  Rowing Pals
//

import SwiftUI
import UIKit

/// The system camera or photo library for a profile picture (decision 29), with iOS's own
/// move-and-scale square so the rower chooses exactly what shows in the circle. The camera
/// starts on the front lens; the rower can flip it.
struct ImagePickerView: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    let onPick: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.allowsEditing = true
        if source == .camera {
            picker.cameraDevice = .front
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                parent.onPick(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
