//
//  NotepadNotesSection.swift
//  Rowing Pals
//

import SwiftUI

/// The notepad's **Notes**, always last on the page (decision 96), with the line saying who sees it.
/// Its own view so typing here redraws only this, not the Scores table and every block above it.
struct NotepadNotesSection: View {
    @Bindable var viewModel: NotepadViewModel

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Notepad.tableRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            Text("Notes")
                .textStyle(Typography.sectionTitle)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            TextField("Anything else from today…", text: $viewModel.notes, axis: .vertical)
                .lineLimit(Tokens.Notepad.notesMinLines...)
                .textStyle(Typography.body)
                .foregroundStyle(Tokens.Ink.primary)
                .padding(Tokens.Spacing.card)
                .background(Self.shape.fill(Tokens.Surface.card))
                .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                .accessibilityLabel("Notes")
            Text("Only your club’s coaches see this page. None of it counts towards anyone’s volume, pieces or PBs.")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 4)
        }
        .padding(.top, Tokens.Spacing.loose)
        .onChange(of: viewModel.notes) { viewModel.pageChanged() }
    }
}
