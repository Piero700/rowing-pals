//
//  DesignSystemPreview.swift
//  Rowing Pals
//
//  A reference screen for every token in DesignSystem, plus GlassSurface over a photo.
//  Not part of the app's navigation — for design verification only.

import SwiftUI

struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                accentSection
                groundAndTextSection
                typographySection
                glassOverPhotoSection
            }
            .padding(20)
        }
        .background(Tokens.Base.ground)
    }

    private var accentSection: some View {
        section("Accent") {
            HStack(spacing: 16) {
                swatch("Signal", Tokens.Accent.signal)
                swatch("PB Gold", Tokens.Accent.pb)
                swatch("Live Coral", Tokens.Accent.live)
            }
        }
    }

    private var groundAndTextSection: some View {
        section("Ground & Ink") {
            HStack(spacing: 16) {
                swatch("Base dark", Tokens.Base.dark)
                swatch("Base light", Tokens.Base.light)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Primary text").textStyle(Typography.body).foregroundStyle(Tokens.Ink.primary)
                Text("Secondary text").textStyle(Typography.body).foregroundStyle(Tokens.Ink.secondary)
            }
        }
    }

    private var typographySection: some View {
        section("Typography") {
            VStack(alignment: .leading, spacing: 10) {
                Text("16,000m")
                    .textStyle(Typography.displayNumeral)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Body 17pt — steady state + rate ladder")
                    .textStyle(Typography.body)
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Secondary 15pt — three segments, photo-verified")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                Text("Senior · M")
                    .textStyle(Typography.label)
                    .foregroundStyle(Tokens.Ink.primary)
            }
        }
    }

    private var glassOverPhotoSection: some View {
        section("Glass over photo") {
            ZStack(alignment: .bottom) {
                simulatedMonitorPhoto
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("16,000m")
                            .textStyle(Typography.displayNumeral)
                            .tabularNumerals()
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Photo-verified")
                            .textStyle(Typography.label)
                            .foregroundStyle(Tokens.Accent.signal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .glassSurface(cornerRadius: 12)
                    }
                    HStack(spacing: 16) {
                        stat("TIME", "1:04:50")
                        stat("SPLIT", "2:01.6")
                        stat("RATE", "r19")
                    }
                }
                .padding(16)
                .glassSurface(cornerRadius: 20)
                .padding(12)
            }
        }
    }

    private var simulatedMonitorPhoto: some View {
        // Stand-in for a real erg monitor photo — busy enough to show diffusion.
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1B2530), Color(hex: 0x05070A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            HStack(spacing: 24) {
                ForEach(["4.7", "16,000", "1:04:50", "19"], id: \.self) { digits in
                    Text(digits)
                        .font(.system(size: 54, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.08))
                        .rotationEffect(.degrees(-8))
                }
            }
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 96))
                .foregroundStyle(.white.opacity(0.18))
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).textStyle(Typography.label).foregroundStyle(.white.opacity(0.6))
            Text(value).textStyle(Typography.bodySecondary).tabularNumerals().foregroundStyle(.white)
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
                // Base dark/light can match the page ground exactly; a hairline keeps the swatch legible.
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Tokens.Ink.secondary.opacity(0.25), lineWidth: 1)
                )
                .frame(width: 64, height: 64)
            Text(name).textStyle(Typography.bodySecondary).foregroundStyle(Tokens.Ink.secondary)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).textStyle(Typography.label).foregroundStyle(Tokens.Ink.secondary)
            content()
        }
    }
}

#Preview("Dark") {
    DesignSystemPreview().preferredColorScheme(.dark)
}

#Preview("Light") {
    DesignSystemPreview().preferredColorScheme(.light)
}
