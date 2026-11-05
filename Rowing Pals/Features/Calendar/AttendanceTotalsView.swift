//
//  AttendanceTotalsView.swift
//  Rowing Pals
//

import SwiftUI

/// Attendance totals (CoachAttendance; decision 39), from the coach's Profile: the current term
/// with Edit dates, This term · 4 weeks · Custom, then By squad and By rower, lowest first.
struct AttendanceTotalsView: View {
    @State private var viewModel = AttendanceTotalsViewModel()
    @State private var isEditingTerms = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigate) private var navigate

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                termCard
                PillSegmentedControl(
                    options: AttendanceTotalsViewModel.Span.allCases.map(\.label),
                    selection: Binding(
                        get: { viewModel.span.rawValue },
                        set: { viewModel.span = AttendanceTotalsViewModel.Span(rawValue: $0) ?? .term }
                    ),
                    compact: true
                )
                .padding(.top, Tokens.Spacing.loose)

                if viewModel.span == .custom {
                    GroupedSection {
                        GroupedRow(label: "From") {
                            DatePicker("From", selection: $viewModel.customFrom, displayedComponents: .date)
                                .labelsHidden()
                        }
                        GroupedDivider()
                        GroupedRow(label: "To") {
                            DatePicker("To", selection: $viewModel.customTo, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .padding(.top, Tokens.Spacing.loose)
                    .onChange(of: viewModel.customFrom) { Task { await viewModel.loadMarks() } }
                    .onChange(of: viewModel.customTo) { Task { await viewModel.loadMarks() } }
                }

                if viewModel.range == nil && viewModel.hasLoaded {
                    FormFootnote("Set this term’s dates with Edit dates, or choose 4 weeks or Custom.")
                        .padding(.top, Tokens.Spacing.loose)
                } else if viewModel.hasLoaded {
                    FormSectionTitle("By squad")
                    if viewModel.squadLines.isEmpty {
                        FormFootnote("No squads yet.")
                    } else {
                        listCard(viewModel.squadLines, opensRower: false)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        FormSectionTitle("By rower")
                        Spacer(minLength: 0)
                        Text("Lowest first")
                            .textStyle(Typography.statLabel)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .padding(.top, Tokens.Spacing.group)
                    }
                    if viewModel.rowerLines.isEmpty {
                        FormFootnote("No registers taken in these dates yet.")
                    } else {
                        listCard(viewModel.rowerLines, opensRower: true)
                    }

                    FormFootnote("Present and Late count as attended. Excused practices are left out of the total.")
                        .padding(.top, Tokens.Spacing.tight)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Attendance") { dismiss() } }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $isEditingTerms, onDismiss: { Task { await viewModel.reloadTerms() } }) {
            TermsEditorView()
        }
    }

    private var termCard: some View {
        HStack(spacing: Tokens.Spacing.loose) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current term")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                Text(viewModel.termText)
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Edit dates") { isEditingTerms = true }
                .buttonStyle(.rpPill(isOn: false))
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }

    private func listCard(_ lines: [AttendanceTotalsViewModel.Line], opensRower: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                if index > 0 {
                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                }
                let row = HStack(spacing: Tokens.Spacing.loose) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.name)
                            .textStyle(Typography.rowTitle)
                            .foregroundStyle(Tokens.Ink.primary)
                            .lineLimit(1)
                        Text(line.detail)
                            .textStyle(Typography.meta)
                            .tabularNumerals()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(line.totals.percentText ?? "–")
                        .textStyle(Typography.rowTitle)
                        .tabularNumerals()
                        .foregroundStyle(Tokens.Ink.primary)
                }
                .padding(.horizontal, Tokens.Spacing.card)
                .padding(.vertical, Tokens.Spacing.loose)
                .frame(minHeight: Tokens.Size.row)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
                if opensRower {
                    row.asButton { navigate(.coachRower(line.id)) }
                } else {
                    row
                }
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: Tokens.Grouped.hairline) }
    }
}
