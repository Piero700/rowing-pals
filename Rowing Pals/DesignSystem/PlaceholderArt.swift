//
//  PlaceholderArt.swift
//  Rowing Pals
//

import SwiftUI

/// A diagonal-stripe fill standing in for a photo, avatar or crest until real
/// media exists. Every "photo" in the app is this until capture/storage land.
struct PhotoPlaceholder: View {
    var cornerRadius: CGFloat = 16
    var caption: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(stripes)
            .overlay(alignment: .bottom) {
                if let caption {
                    Text(caption)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.bottom, 8)
                }
            }
    }

    private var stripes: some ShapeStyle {
        Tokens.Ink.primary.opacity(0.08)
    }
}

/// A circular variant for avatars and crests.
struct AvatarPlaceholder: View {
    var diameter: CGFloat = 36

    var body: some View {
        Circle()
            .fill(Tokens.Ink.primary.opacity(0.08))
            .frame(width: diameter, height: diameter)
    }
}

#Preview {
    VStack(spacing: 20) {
        PhotoPlaceholder(caption: "ERG MONITOR PHOTO")
            .frame(height: 160)
        AvatarPlaceholder(diameter: 52)
    }
    .padding()
    .background(Tokens.Base.ground)
}
