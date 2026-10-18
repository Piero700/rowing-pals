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

    private static let rowShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

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
            ScreenHeader(title: viewModel.isNew ? "New challenge" : "Challenge") { dismiss() }
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

    @ViewBuilder
    private var form: some View {
        FormLabel("Kind").padding(.top, Tokens.Spacing.card)
        PillSegmentedControl(options: ChallengeKind.allCases.map(\.label), selection: Binding(
            get: { ChallengeKind.allCases.firstIndex(of: viewModel.kind) ?? 0 },
            set: { viewModel.kind = ChallengeKind.allCases[$0] }
        ), compact: true)
        FormFootnote(viewModel.kind.explanation + " Erg metres on the leaderboards count, as in Rankings.")

        FormLabel("Name").padding(.top, Tokens.Spacing.card)
        TextField(placeholder, text: $viewModel.title)
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()

        if viewModel.kind == .squads {
            FormLabel("Squads").padding(.top, Tokens.Spacing.card)
            squadPicker
            FormFootnote("Ranked on metres per rower, so a bigger squad doesn’t win by size. Someone in two of them counts for both.")
        } else {
            FormLabel(viewModel.kind == .target ? "Metres each" : "Metres together").padding(.top, Tokens.Spacing.card)
            HStack {
                TextField(viewModel.kind == .target ? "100000" : "2000000", text: $viewModel.targetText)
                    .keyboardType(.numberPad)
                    .tabularNumerals()
                    .onChange(of: viewModel.targetText) { viewModel.targetText = String(viewModel.targetText.filter(\.isNumber).prefix(9)) }
                Text("metres")
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .textStyle(Typography.bodyV3)
            .padding(.horizontal, Tokens.Spacing.card)
            .formFieldBox()
            if let target = viewModel.targetM, target > 0 {
                FormFootnote("That’s \(target.formattedMetres) (\(target.formattedDistance(unit: .kilometres))).")
            }
        }

        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 0) {
                FormLabel("Starts")
                DatePicker("Starts", selection: $viewModel.startsOn, displayedComponents: .date)
                    .labelsHidden()
                    .formFieldBox()
            }
            VStack(alignment: .leading, spacing: 0) {
                FormLabel("Ends")
                DatePicker("Ends", selection: $viewModel.endsOn, in: viewModel.startsOn..., displayedComponents: .date)
                    .labelsHidden()
                    .formFieldBox()
            }
        }
        .padding(.top, Tokens.Spacing.card)
        FormFootnote("Both days count. Every rower in your club is in it; it shows in Rankings and on their Feed while it’s on.")

        if let problem = viewModel.problem, !viewModel.title.isEmpty {
            Text(problem)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.loose)
        }
        if let error = viewModel.errorMessage {
            Text(error)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.System.error)
                .padding(.horizontal, 4)
                .padding(.top, Tokens.Spacing.loose)
        }

        Button {
            Task { if await viewModel.save() { dismiss() } }
        } label: {
            if viewModel.isSaving {
                ProgressView().tint(Tokens.Ink.onBrand)
            } else {
                Text(viewModel.isNew ? "Set challenge" : "Save changes")
            }
        }
        .buttonStyle(.rpPrimary)
        .disabled(viewModel.isSaving || viewModel.problem != nil)
        .padding(.top, Tokens.Spacing.group)

        if !viewModel.isNew {
            Button("Delete challenge") { isConfirmingDelete = true }
                .buttonStyle(.rpDestructive)
                .disabled(viewModel.isSaving)
                .padding(.top, Tokens.Spacing.tight)
        }
        FormFootnote("Coaches, the owner, co-owners and admins can set, change and delete challenges.")
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private var placeholder: String {
        switch viewModel.kind {
        case .target: "100km in November"
        case .clubTotal: "2,000km as a club this term"
        case .squads: "Squad battle: Michaelmas"
        }
    }

    @ViewBuilder
    private var squadPicker: some View {
        if viewModel.squads.isEmpty {
            Text("Your club has no squads yet. Coaches, the owner and co-owners make them in Squads.")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.squads.enumerated()), id: \.element.id) { index, squad in
                    if index > 0 { Rectangle().fill(Tokens.Surface.line).frame(height: 1) }
                    let isOn = viewModel.squadIds.contains(squad.id)
                    Button {
                        if isOn { viewModel.squadIds.remove(squad.id) } else { viewModel.squadIds.insert(squad.id) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(squad.name)
                                    .textStyle(Typography.rowTitle)
                                    .foregroundStyle(Tokens.Ink.primary)
                                Text("\(squad.memberIds.count) rower\(squad.memberIds.count == 1 ? "" : "s")")
                                    .textStyle(Typography.meta)
                                    .tabularNumerals()
                                    .foregroundStyle(Tokens.Ink.secondary)
                            }
                            Spacer(minLength: 0)
                            RPIconView(icon: isOn ? .checkboxOn : .checkbox, size: Tokens.Icon.regular)
                                .foregroundStyle(isOn ? Tokens.Accent.brand : Tokens.Ink.secondary)
                        }
                        .padding(.horizontal, Tokens.Spacing.card)
                        .frame(minHeight: Tokens.Size.row)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
            .background(Self.rowShape.fill(Tokens.Surface.card))
            .clipShape(Self.rowShape)
            .overlay { Self.rowShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        }
    }
}
