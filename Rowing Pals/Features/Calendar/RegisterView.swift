//
//  RegisterView.swift
//  Rowing Pals
//

import SwiftUI

/// Take the register (CoachPracticeRegister; decision 39): the practice with its present, late,
/// absent and excused counts; then everyone it's for with what they said, whether they checked in
/// or posted a session, any earlier change to their mark, and Present · Late · Absent · Excused.
struct RegisterView: View {
    @State private var viewModel: RegisterViewModel
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    init(practiceId: UUID) {
        _viewModel = State(initialValue: RegisterViewModel(practiceId: practiceId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let practice = viewModel.practice {
                    summary(practice)
                    Text("“Suggested” ticks come from sessions posted today: check them before saving. Your mark always counts over the rower’s own answer.")
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                        .fixedSize(horizontal: false, vertical: true)
                        .guidance()

                    Text("\(viewModel.squadText) · \(viewModel.rows.count)")
                        .textStyle(Typography.sectionTitle)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.sectionTop)
                        .padding(.bottom, Tokens.Spacing.tight)
                        .accessibilityAddTraits(.isHeader)

                    if viewModel.rows.isEmpty {
                        Text("Nobody is in the squads this practice is for.")
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                                if index > 0 {
                                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                                }
                                rowView(row)
                            }
                        }
                        .background(Self.cardShape.fill(Tokens.Surface.card))
                        .clipShape(Self.cardShape)
                        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
                    }

                    if let error = viewModel.errorMessage {
                        errorText(error)
                    }

                    Button {
                        Task { if await viewModel.save() { dismiss() } }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().tint(Tokens.Ink.onBrand)
                        } else {
                            Text("Save register")
                        }
                    }
                    .buttonStyle(.rpPrimary)
                    .disabled(viewModel.isSaving || viewModel.rows.isEmpty)
                    .padding(.top, Tokens.Spacing.group)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = viewModel.errorMessage {
                    errorText(error)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Register") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }

    private func summary(_ practice: Practice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(practice.displayTitle)
                    .textStyle(Typography.profileName)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: Tokens.Spacing.tight)
                BrandChip(text: viewModel.squadText)
            }
            Text(viewModel.whenText)
                .textStyle(Typography.meta)
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.top, 2)
            HStack(spacing: 4) {
                ForEach(RegisterMark.allCases, id: \.self) { mark in
                    VStack(spacing: 2) {
                        Text("\(viewModel.count(of: mark))")
                            .textStyle(Typography.coachStatSmall)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.primary)
                        Text(mark.label.lowercased())
                            .textStyle(Typography.statLabel)
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, Tokens.Spacing.loose)
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    private func rowView(_ row: RegisterViewModel.Row) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Spacing.loose) {
                AvatarPlaceholder(diameter: Tokens.Size.rowIcon, name: row.member.displayName, userId: row.member.id)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.member.displayName)
                        .textStyle(Typography.rowTitle)
                        .foregroundStyle(Tokens.Ink.primary)
                        .lineLimit(1)
                    Text(row.line)
                        .textStyle(Typography.meta)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.secondary)
                    if let change = row.changeLine {
                        Text(change)
                            .textStyle(Typography.meta)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if row.isSuggested && viewModel.marks[row.id] == .present {
                BrandChip(text: "Suggested")
                    .padding(.top, Tokens.Spacing.tight)
            }
            PillSegmentedControl(
                options: RegisterMark.allCases.map(\.label),
                selection: Binding(
                    get: { viewModel.marks[row.id].flatMap { RegisterMark.allCases.firstIndex(of: $0) } ?? -1 },
                    set: { viewModel.set(RegisterMark.allCases[$0], for: row.id) }
                ),
                compact: true
            )
            .padding(.top, Tokens.Spacing.loose)
        }
        .padding(.horizontal, Tokens.Spacing.card)
        .padding(.vertical, Tokens.Spacing.loose)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.System.error)
            .padding(.horizontal, 4)
            .padding(.top, Tokens.Spacing.loose)
    }
}
