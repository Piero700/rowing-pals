//
//  GlassPreview.swift
//  Rowing Pals
//

import SwiftUI

/// Reference screen for task 02 — a glass card, a `.glass` button and a
/// `.glassProminent` button, all layered over a photo. Not part of the app's
/// navigation — for design verification only.
struct GlassPreview: View {
    var body: some View {
        ZStack {
            Tokens.Base.dark.ignoresSafeArea()

            // The busy detail sits directly behind the glass, not off in a
            // corner — refraction only reads clearly over real texture.
            simulatedMonitorPhoto
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(.horizontal, 16)

            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    glassCard

                    HStack(spacing: 12) {
                        Button("Cancel") {}
                            .buttonStyle(.glass)

                        Button("Post") {}
                            .buttonStyle(.glassProminent)
                            .tint(Tokens.Accent.signal)
                    }
                }
                .padding(20)
            }
        }
    }

    private var glassCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("16,000m")
                .textStyle(Typography.displayNumeral)
                .tabularNumerals()
                .foregroundStyle(.white)
            Text("Glass card — .glassEffect(.regular, in:)")
                .textStyle(Typography.bodySecondary)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 24)
    }

    private var simulatedMonitorPhoto: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1B2530), Color(hex: 0x05070A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            HStack(spacing: 24) {
                ForEach(["4.7", "16,000", "1:04:50", "19"], id: \.self) { digits in
                    Text(digits)
                        .font(.system(size: 54, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.28))
                        .rotationEffect(.degrees(-8))
                }
            }
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 96))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

#Preview {
    GlassPreview()
}
