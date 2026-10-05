//
//  EditProfileView.swift
//  Rowing Pals
//

import SwiftUI
import UIKit

/// Settings → Account → Edit profile, to the v4 SettingsProfile artboard (decisions 34–36):
/// the profile picture, name, **account type** (I row / Coach only), the rankings group (gender
/// and level — hidden for a coach-only account), date of birth and bodyweight (seen only by the
/// rower and their club's coaches), and the weekly target in km. Saved with Save.
///
/// The canvas draws age as "years"; the app keeps **date of birth** (decision 35), so it stays
/// right every year.
struct EditProfileView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var isChoosingPhoto = false
    @State private var photoSource: PhotoSource?
    @State private var isSavingPhoto = false
    @State private var photoError: String?

    private enum Field { case name, weight, target }

    /// Where a new profile picture comes from (decision 29).
    private enum PhotoSource: Identifiable {
        case camera, library
        var id: Self { self }
        var pickerSource: UIImagePickerController.SourceType { self == .camera ? .camera : .photoLibrary }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                photo
                    .frame(maxWidth: .infinity)

                sectionTitle("Name")
                    .padding(.top, Tokens.Spacing.screen)
                TextField("Your name", text: $viewModel.displayName)
                    .textStyle(Typography.bodyV3)
                    .focused($focusedField, equals: .name)
                    .padding(.horizontal, Tokens.Spacing.card)
                    .frame(minHeight: Tokens.Size.input)
                    .background(field.fill(Tokens.Surface.card))
                    .overlay { field.strokeBorder(Tokens.Surface.line, lineWidth: 1) }

                SettingsGroup(title: "Account type") {
                    stackedRow(title: "How you use Rowing Pals", subtitle: "Coaches who don’t row skip rankings and have no Log button.") {
                        PillSegmentedControl(options: ["I row", "Coach only"], selection: Binding(
                            get: { viewModel.isRower ? 0 : 1 },
                            set: { viewModel.isRower = $0 == 0 }
                        ), compact: true)
                    }
                }

                if viewModel.isRower {
                    SettingsGroup(
                        title: "Rankings",
                        footnote: "Rankings compare you with rowers of the same gender and level. You can change your level at any time."
                    ) {
                        stackedRow(title: "Gender", subtitle: nil) {
                            PillSegmentedControl(options: ["Male", "Female"], selection: Binding(
                                get: { viewModel.gender == .female ? 1 : 0 },
                                set: { viewModel.gender = $0 == 1 ? .female : .male }
                            ), compact: true)
                        }
                        Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                        stackedRow(title: "Level", subtitle: "Novice means you’re in your first season.") {
                            PillSegmentedControl(options: ["Novice", "Senior"], selection: Binding(
                                get: { viewModel.category == .senior ? 1 : 0 },
                                set: { viewModel.category = $0 == 1 ? .senior : .novice }
                            ), compact: true)
                        }
                    }
                }

                sectionTitle("About you")
                    .padding(.top, Tokens.Spacing.group)
                HStack(spacing: Tokens.Spacing.loose) {
                    birthDateField
                    weightField
                }
                footnote("Visible to you and your club’s coaches. Bodyweight is used for watts per kilo.")
                if let weightProblem = viewModel.weightProblem {
                    problem(weightProblem)
                }

                sectionTitle("Weekly target")
                    .padding(.top, Tokens.Spacing.group)
                HStack(spacing: Tokens.Spacing.tight) {
                    TextField("0", text: $viewModel.weeklyTargetText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .target)
                        .textStyle(Typography.bodyV3)
                        .tabularNumerals()
                    Text("km")
                        .textStyle(Typography.detail)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
                .padding(.horizontal, Tokens.Spacing.card)
                .frame(minHeight: Tokens.Size.input)
                .background(field.fill(Tokens.Surface.card))
                .overlay { field.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
                footnote("Your weekly volume goal. Any logged session counts towards it.")
                if let targetProblem = viewModel.weeklyTargetProblem {
                    problem(targetProblem)
                }

                if let saveError = viewModel.saveError {
                    problem(saveError)
                }

                Button {
                    focusedField = nil
                    Task {
                        await viewModel.save()
                        if viewModel.saveError == nil { dismiss() }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(Tokens.Ink.onBrand)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.rpPrimary)
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                .padding(.top, Tokens.Spacing.group)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Edit profile") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
    }

    // MARK: - Photo

    /// The 88 pt picture and "Change photo" (decision 29: camera, library or remove).
    private var photo: some View {
        VStack(spacing: 4) {
            AvatarPlaceholder(diameter: Tokens.Size.editProfileAvatar, name: viewModel.displayName, userId: viewModel.userId)
            Button("Change photo") { isChoosingPhoto = true }
                .buttonStyle(.rpText)
                .disabled(isSavingPhoto || viewModel.userId == nil)
            if let photoError {
                problem(photoError)
            }
        }
        .confirmationDialog("Profile picture", isPresented: $isChoosingPhoto, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take photo") { photoSource = .camera }
            }
            Button("Choose from library") { photoSource = .library }
            if let id = viewModel.userId, AvatarStore.shared.url(for: id) != nil {
                Button("Remove photo", role: .destructive) { Task { await changePhoto(nil) } }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $photoSource) { source in
            ImagePickerView(source: source.pickerSource) { image in
                Task { await changePhoto(image) }
            }
            .ignoresSafeArea()
        }
    }

    /// Sets the picture, or removes it with nil.
    private func changePhoto(_ image: UIImage?) async {
        isSavingPhoto = true
        photoError = nil
        defer { isSavingPhoto = false }
        do {
            if let image {
                try await AvatarService.setPicture(image)
            } else {
                try await AvatarService.removePicture()
            }
        } catch {
            photoError = error.localizedDescription
        }
    }

    // MARK: - About you

    private var birthDateField: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            if let birthDate = viewModel.birthDate {
                DatePicker(
                    "Date of birth",
                    selection: Binding(get: { birthDate }, set: { viewModel.birthDate = $0 }),
                    in: Self.birthDateRange,
                    displayedComponents: .date
                )
                .labelsHidden()
                Spacer(minLength: 0)
                Button {
                    viewModel.birthDate = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Ink.secondary)
                        .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                }
                .buttonStyle(IconPressStyle())
                .accessibilityLabel("Remove date of birth")
            } else {
                Button("Date of birth") { viewModel.birthDate = Self.suggestedBirthDate }
                    .buttonStyle(.rpText)
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, Tokens.Spacing.card)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.input)
        .background(field.fill(Tokens.Surface.card))
        .overlay { field.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
    }

    private var weightField: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            TextField("Weight", text: $viewModel.weightText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
                .textStyle(Typography.bodyV3)
                .tabularNumerals()
            Text("kg")
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.secondary)
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.input)
        .background(field.fill(Tokens.Surface.card))
        .overlay { field.strokeBorder(Tokens.Surface.line, lineWidth: 1) }
    }

    /// Born 1900 or later, and at least 5 years old (the engine's own range).
    private static var birthDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let earliest = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast
        let latest = calendar.date(byAdding: .year, value: -5, to: Date()) ?? Date()
        return earliest...latest
    }

    /// Where the picker starts when a date is first added.
    private static var suggestedBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    }

    // MARK: - Building blocks

    private var field: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, Tokens.Spacing.tight)
            .accessibilityAddTraits(.isHeader)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.tight)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func problem(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.System.error)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.tight)
    }

    /// v4 stacked row: title and optional description above a full-width control.
    private func stackedRow<Control: View>(title: String, subtitle: String?, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            control()
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.top, Tokens.Spacing.gap)
        .padding(.bottom, Tokens.Spacing.loose)
    }
}
