//
//  EditProfileView.swift
//  Rowing Pals
//

import SwiftUI
import UIKit

/// Settings → Account → Edit profile, to the v4 SettingsProfile artboard (decisions 34–36):
/// the profile picture, name, **account type** (I row / Coach only), the rankings group (gender
/// level and side), date of birth and bodyweight (seen only by the rower and their club's
/// coaches), and the weekly target in km — all but name and account type hidden for a
/// coach-only account. Saved with Save.
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

                GroupedSection {
                    GroupedRow(label: "Name") {
                        TextField("Your name", text: $viewModel.displayName)
                            .textStyle(Typography.detail)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .name)
                    }
                    GroupedDivider()
                    // Shown as @username; you can sign in with it (decision 85).
                    GroupedRow(label: "Username") {
                        HStack(spacing: 2) {
                            Spacer(minLength: 0)
                            Text("@")
                                .textStyle(Typography.detail)
                                .foregroundStyle(Tokens.Ink.secondary)
                            // As wide as what's typed, so "@" stays beside it, against the right edge.
                            Text(viewModel.username.isEmpty ? "username" : viewModel.username)
                                .textStyle(Typography.detail)
                                .hidden()
                                .overlay {
                                    TextField("username", text: $viewModel.username)
                                        .textStyle(Typography.detail)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .textContentType(.username)
                                }
                        }
                    }
                    .task(id: viewModel.username) {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        await viewModel.checkUsername()
                    }
                }
                .padding(.top, Tokens.Spacing.loose)
                if let note = viewModel.usernameNote {
                    Text(note)
                        .textStyle(Typography.statLabel)
                        .foregroundStyle(viewModel.usernameIsFree ? Tokens.Accent.success : Tokens.System.error)
                        .padding(.horizontal, Tokens.Grouped.rowPadding)
                        .padding(.top, Tokens.Grouped.headerGap)
                } else {
                    GroupedNote(text: "People can find you by it, and you can sign in with it instead of your email.")
                        .padding(.top, Tokens.Grouped.headerGap)
                        .guidance()
                }

                SettingsGroup(title: "Account type") {
                    stackedRow(title: "How you use Rowing Pals", subtitle: nil) {
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
                        Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline)
                        stackedRow(title: "Level", subtitle: "Novice means you’re in your first season.") {
                            PillSegmentedControl(options: ["Novice", "Senior"], selection: Binding(
                                get: { viewModel.category == .senior ? 1 : 0 },
                                set: { viewModel.category = $0 == 1 ? .senior : .novice }
                            ), compact: true)
                        }
                        Rectangle().fill(Tokens.Surface.line).frame(height: Tokens.Grouped.hairline)
                        // Decision 67: coaches see it when they seat the rower in a boat.
                        stackedRow(title: "Side", subtitle: "The side you row on in sweep boats, or Cox if you cox. Your coach sees it when seating you.") {
                            PillSegmentedControl(options: RowingSide.allCases.map(\.label), selection: Binding(
                                get: { viewModel.side.flatMap { RowingSide.allCases.firstIndex(of: $0) } ?? -1 },
                                set: { viewModel.side = RowingSide.allCases[$0] }
                            ), compact: true)
                        }
                    }
                }

                // Date of birth, bodyweight and a weekly target only mean something for someone who
                // rows; a coach-only account isn't asked (user, 2026-10-16).
                if viewModel.isRower {
                    GroupedSection(header: "About you",
                                   hint: "Visible to you and your club’s coaches. Bodyweight is used for watts per kilo. Any logged session counts towards your weekly target.") {
                        GroupedRow(label: "Date of birth") { birthDateField }
                        GroupedDivider()
                        GroupedRow(label: "Weight") { weightField }
                        GroupedDivider()
                        GroupedRow(label: "Weekly target") {
                            TextField("0", text: $viewModel.weeklyTargetText)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .target)
                                .multilineTextAlignment(.trailing)
                                .textStyle(Typography.detail)
                                .tabularNumerals()
                            Text("km")
                                .textStyle(Typography.detail)
                                .foregroundStyle(Tokens.Ink.secondary)
                        }
                    }
                    .padding(.top, Tokens.Spacing.group)
                    if let weightProblem = viewModel.weightProblem {
                        problem(weightProblem)
                    }
                    if let targetProblem = viewModel.weeklyTargetProblem {
                        problem(targetProblem)
                    }
                }

                if let saveError = viewModel.saveError {
                    problem(saveError)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "Edit profile", onBack: { dismiss() }) {
                HeaderSaveButton(title: "Save", isSaving: viewModel.isSaving, isDisabled: !viewModel.hasUnsavedChanges) {
                    focusedField = nil
                    Task {
                        await viewModel.save()
                        if viewModel.saveError == nil { dismiss() }
                    }
                }
            }
        }
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
                Button {
                    viewModel.birthDate = nil
                } label: {
                    RPIconView(icon: .clear, size: Tokens.Icon.small)
                        .foregroundStyle(Tokens.Ink.faint)
                        .frame(width: Tokens.Size.iconButton, height: Tokens.Size.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                .accessibilityLabel("Remove date of birth")
            } else {
                Button("Add") { viewModel.birthDate = Self.suggestedBirthDate }
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Accent.brand)
            }
        }
    }

    private var weightField: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            TextField("0", text: $viewModel.weightText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
                .multilineTextAlignment(.trailing)
                .textStyle(Typography.detail)
                .tabularNumerals()
            Text("kg")
                .textStyle(Typography.detail)
                .foregroundStyle(Tokens.Ink.secondary)
        }
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
