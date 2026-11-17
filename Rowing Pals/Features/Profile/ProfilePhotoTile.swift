//
//  ProfilePhotoTile.swift
//  Rowing Pals
//

import SwiftUI

/// One square on Profile's Posts grid: the monitor photo with its distance in the corner. A private
/// post (decision 106) is dimmed under the photo scrim with a crossed-out eye in the middle.
struct ProfilePhotoTile: View {
    let photo: ProfileViewModel.ProfilePhoto
    let url: URL?
    var isPrivate = false

    var body: some View {
        CachedAsyncImage(url: url) {
            PhotoPlaceholder(cornerRadius: 12)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .overlay {
            if isPrivate {
                ZStack {
                    Tokens.Base.photoScrim
                    RPIconView(icon: .eyeOff, size: Tokens.Icon.large)
                        .foregroundStyle(Tokens.Ink.primary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(photo.distanceM.formattedMetres)
                .font(.system(size: 10, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(.white)
                .shadow(radius: 3)
                .padding(6)
        }
        .accessibilityLabel(isPrivate
                            ? "Private workout, \(photo.distanceM.formattedMetres)"
                            : "Workout, \(photo.distanceM.formattedMetres)")
    }
}
