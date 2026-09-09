//
//  CaptureView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 3 — dual camera, live capture only. Static mockup; real
/// `AVCaptureMultiCamSession` wiring arrives with tasks 07/08 on a physical
/// device (the simulator has no camera).
struct CaptureView: View {
    @State private var showReview = false

    var body: some View {
        ZStack(alignment: .bottom) {
            PhotoPlaceholder(cornerRadius: 0, caption: "REAR CAMERA · PM5 MONITOR IN FRAME")
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Tokens.Ink.primary.opacity(0.22), lineWidth: 2)
                .frame(width: 289, height: 230)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 210)

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
                shutterButton
                Text("Log a water session instead")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .padding(.bottom, 6)
            }
            .padding(.bottom, 130)
        }
        .navigationDestination(isPresented: $showReview) {
            ReviewSheetView()
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
            showReview = true
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
