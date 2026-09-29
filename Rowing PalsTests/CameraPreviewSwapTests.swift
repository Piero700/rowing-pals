//
//  CameraPreviewSwapTests.swift
//  Rowing PalsTests
//

import AVFoundation
import Testing
import UIKit
@testable import Rowing_Pals

/// "Flip camera" swaps which preview layer the big view and the inset host. A layer can have
/// only one superlayer, so each view must only ever remove a layer it still holds — otherwise
/// the inset tears the big view's new layer back out and the big preview goes blank for good.
@MainActor
struct CameraPreviewSwapTests {
    @Test func flippingKeepsBothPreviewsOnScreen() {
        let rear = AVCaptureVideoPreviewLayer()
        let front = AVCaptureVideoPreviewLayer()
        let main = CameraPreviewView.PreviewUIView()
        let inset = CameraPreviewView.PreviewUIView()
        main.host(rear)
        inset.host(front)

        for flip in 1...4 {
            let frontIsMain = flip % 2 == 1
            // SwiftUI updates the big view first, then the inset — the order that lost the preview.
            main.host(frontIsMain ? front : rear)
            inset.host(frontIsMain ? rear : front)
            #expect((frontIsMain ? front : rear).superlayer === main.layer, "big preview after flip \(flip)")
            #expect((frontIsMain ? rear : front).superlayer === inset.layer, "inset after flip \(flip)")
        }
    }

    @Test func flippingWithTheInsetUpdatedFirstAlsoWorks() {
        let rear = AVCaptureVideoPreviewLayer()
        let front = AVCaptureVideoPreviewLayer()
        let main = CameraPreviewView.PreviewUIView()
        let inset = CameraPreviewView.PreviewUIView()
        main.host(rear)
        inset.host(front)

        inset.host(rear)
        main.host(front)
        #expect(front.superlayer === main.layer)
        #expect(rear.superlayer === inset.layer)
    }
}
