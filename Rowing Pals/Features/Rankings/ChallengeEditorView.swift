//
//  ChallengeEditorView.swift
//  Rowing Pals
//

import SwiftUI

/// New challenge, or one to change (decision 91): Kind (Personal target · Club total · Squad vs
/// squad), Name, the metres to aim for or the squads, Starts and Ends, then Set challenge or Save
/// changes; editing adds Delete. Every rower in the club is in it.
struct ChallengeEditorView: View {
    @State private var viewModel: ChallengeEditorViewModel
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(challengeId: UUID?) {
        _viewModel = State(initialValue: ChallengeEditorViewModel(challengeId: challengeId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.hasLoaded {
                    form
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: viewModel.isNew ? "New challenge" : "Challenge", onBack: { dismiss() }) {
                HeaderSaveButton(title: viewModel.isNew ? "Set" : "Save", isSaving: viewModel.isSaving,
                                 isDisabled: !viewModel.hasLoaded || viewModel.problem != nil) {
                    Task { if await viewModel.save() { dismiss() } }
                }
            }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .dismissesKeyboardOnTap()
        .task { await viewModel.load() }
        .alert("Delete this challenge?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It goes from Rankings and every Feed. Nobody’s metres change.")
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Grouped.groupGap) {
            GroupedSection(footer: viewModel.kind.explanation + " Erg metres on the leaderboards count, as in Rankings.") {
                GroupedRow(label: "Kind") {
                    Menu {
                        Picker("Kind", selection: $viewModel.kind) {
                            ForEach(ChallengeKind.allCases, id: \.self) { kind in Text(kind.label).tag(kind) }
                        }
                    } label: {
                        GroupedValue(text: viewModel.kind.label)
                    }
                }
                GroupedDivider()
                GroupedTextRow(label: "Name", placeholder: placeholder, text: $viewModel.title)
                if viewModel.kind != .squads {
                    GroupedDivider()
                    GroupedRow(label: viewModel.kind == .target ? "Metres each" : "Metres together") {
                        TextField(viewModel.kind == .target ? "100000" : "2000000", text: $viewModel.targetText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .textStyle(Typography.detail)
                            .tabularNumerals()
                            .onChange(of: viewModel.targetText) {
                                viewModel.targetText = String(viewModel.targetText.filter(\.isNumber).prefix(9))
                            }
                        Text("m")
                            .textStyle(Typography.detail)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
            }
            .groupedFooter(viewModel.kind != .squads
                ? viewModel.targetM.flatMap { $0 > 0 ? "That’s \($0.formattedMetres) (\($0.formattedDistance(unit: .kilometres)))." : nil }
                : nil)

            if viewModel.kind == .squads {
                squadPicker
            }

            GroupedSection(footer: "Both days count. Every rower in your club is in it; it shows in Rankings and on their Feed while it’s on.") {
                GroupedRow(label: "Starts") {
                    DatePicker("Starts", selection: $viewModel.startsOn, displayedComponents: .date)
                        .labelsHidden()
                }
                GroupedDivider()
                GroupedRow(label: "Ends") {
                    DatePicker("Ends", selection: $viewModel.endsOn, in: viewModel.startsOn..., displayedComponents: .date)
                        .labelsHidden()
                }
            }

            if let problem = viewModel.problem, !viewModel.title.isEmpty { GroupedError(text: problem) }
            if let error = viewModel.errorMessage { GroupedError(text: error) }

            if viewModel.isNew {
                GroupedNote(text: "Coaches, the owner, co-owners and admins can set, change and delete challenges.")
            } else {
                GroupedSection(footer: "Coaches, the owner, co-owners and admins can set, change and delete challenges.") {
                    GroupedButtonRow(title: "Delete challenge", isDestructive: true, isCentred: true) { isConfirmingDelete = true }
                        .disabled(viewModel.isSaving)
                }
            }
        }
        .padding(.top, Tokens.Spacing.tight)
    }

    private var placeholder: String {
        switch viewModel.kind {
        case .target: "100km in November"
        case .clubTotal: "2,000km as a club this term"
        case .squads: "Squad battle: Michaelmas"
        }
    }

    private var squadPicker: some View {
        GroupedSection(header: "Squads",
                       footer: viewModel.squads.isEmpty
                        ? "Your club has no squads yet. Coaches, the owner and co-owners make them in Squads."
                        : "Ranked on metres per rower, so a bigger squad doesn’t win by size. Someone in two of them counts for both.") {
            ForEach(Array(viewModel.squads.enumerated()), id: \.element.id) { index, squad in
                if index > 0 { GroupedDivider() }
                let isOn = viewModel.squadIds.contains(squad.id)
                Button {
                    if isOn { viewModel.squadIds.remove(squad.id) } else { viewModel.squadIds.insert(squad.id) }
                } label: {
                    GroupedRow(label: squad.name) {
                        Text("\(squad.memberIds.count) rower\(squad.memberIds.count == 1 ? "" : "s")")
                            .textStyle(Typography.detail)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                        RPIconView(icon: .check, size: Tokens.Icon.small)
                            .foregroundStyle(Tokens.Accent.brand)
                            .opacity(isOn ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(IconPressStyle())
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
