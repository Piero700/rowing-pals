//
//  ProfileAvatar.swift
//  Rowing Pals
//

import SwiftUI

/// Profile's 76 pt avatar. Your own is a button: tap it to take a new picture, choose one from your
/// library, or remove it (decision 29); a small camera badge says so. Anyone else's is just their avatar.
struct ProfileAvatar: View {
    /// Where a new profile picture comes from (decision 29).
    private enum PhotoSource: Identifiable {
        case camera, library
        var id: Self { self }
        var pickerSource: UIImagePickerController.SourceType { self == .camera ? .camera : .photoLibrary }
    }

    let viewModel: ProfileViewModel
    let isOtherRower: Bool

    @State private var isChoosingPhoto = false
    @State private var photoSource: PhotoSource?
    @State private var isSavingPhoto = false
    @State private var photoError: String?

    var body: some View {
        let picture = AvatarPlaceholder(
            diameter: 76,
            streakDays: viewModel.streakDays,
            name: viewModel.displayName,
            userId: viewModel.profileUserId
        )
        if viewModel.isOwnProfile && !isOtherRower {
            Button { isChoosingPhoto = true } label: {
                picture
                    .overlay {
                        if isSavingPhoto {
                            Circle().fill(Tokens.Base.ground.opacity(0.55))
                            ProgressView().tint(Tokens.Ink.primary)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        RPIconView(icon: .camera, size: Tokens.Icon.small)
                            .textStyle(Typography.fieldLabel)
                            .foregroundStyle(Tokens.Ink.onBrand)
                            .frame(width: Tokens.Size.avatarBadge, height: Tokens.Size.avatarBadge)
                            .background(Circle().fill(Tokens.Accent.brand))
                            .overlay { Circle().strokeBorder(Tokens.Base.ground, lineWidth: 2) }
                            .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(IconPressStyle())
            .disabled(isSavingPhoto)
            .accessibilityLabel("Change profile picture")
            .confirmationDialog("Profile picture", isPresented: $isChoosingPhoto, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take photo") { photoSource = .camera }
                }
                Button("Choose from library") { photoSource = .library }
                if let id = viewModel.profileUserId, AvatarStore.shared.url(for: id) != nil {
                    Button("Remove photo", role: .destructive) { Task { await removePhoto() } }
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(item: $photoSource) { source in
                ImagePickerView(source: source.pickerSource) { image in
                    Task { await savePhoto(image) }
                }
                .ignoresSafeArea()
            }
            if let photoError {
                Text(photoError)
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.System.error)
                    .multilineTextAlignment(.center)
                    .padding(.top, Tokens.Spacing.tight)
            }
        } else {
            picture
        }
    }

    private func savePhoto(_ image: UIImage) async {
        isSavingPhoto = true
        photoError = nil
        defer { isSavingPhoto = false }
        do {
            try await AvatarService.setPicture(image)
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func removePhoto() async {
        isSavingPhoto = true
        photoError = nil
        defer { isSavingPhoto = false }
        do {
            try await AvatarService.removePicture()
        } catch {
            photoError = error.localizedDescription
        }
    }
}
