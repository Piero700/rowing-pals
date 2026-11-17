//
//  ProfilePhotoTile.swift
//  Rowing Pals
//

import SwiftUI

/// One square on Profile's Posts grid: the monitor photo with its distance in the corner.
struct ProfilePhotoTile: View {
    let photo: ProfileViewModel.ProfilePhoto
    let url: URL?

    var body: some View {
        CachedAsyncImage(url: url) {
            PhotoPlaceholder(cornerRadius: 12)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(photo.distanceM.formattedMetres)
                .font(.system(size: 10, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .padding(6)
        }
        .accessibilityLabel("Workout, \(photo.distanceM.formattedMetres)")
    }
}
