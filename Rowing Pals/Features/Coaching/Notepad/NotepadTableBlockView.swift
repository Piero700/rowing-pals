//
//  NotepadTableBlockView.swift
//  Rowing Pals
//

import SwiftUI

/// A table a coach added to the notepad (decision 96): its name, a heading row and the rows under
/// it, every box typed into directly; **+ Row** and **+ Column** (up to five columns) and ✕ to take
/// it off the page. The columns share the card's width equally, as on the board.
struct NotepadTableBlockView: View {
    @Binding var block: NotepadBlock
    let onAddRow: () -> Void
    let onAddColumn: () -> Void
    let onRemove: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: Tokens.Notepad.tableRadius, style: .continuous)
    private static let line = Rectangle().fill(Tokens.Surface.cardEdge)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Tokens.Spacing.tight) {
                TextField("Table name", text: $block.title)
                    .textStyle(Typography.rowTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                    .onChange(of: block.title) { _, value in
                        let clipped = NotepadRules.clipped(value, to: NotepadRules.maxTitleLength)
                        if clipped != value { block.title = clipped }
                    }
                NotepadRemoveButton(label: "Remove table", action: onRemove)
            }
            .padding(.leading, Tokens.Spacing.card)

            // As on the board, the columns share the card's width equally (up to five fit).
            VStack(alignment: .leading, spacing: 0) {
                ForEach(block.cells.indices, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(block.cells[row].indices, id: \.self) { column in
                            box(row: row, column: column)
                        }
                    }
                    .background(row == 0 ? Tokens.Surface.raised : Color.clear)
                    .overlay(alignment: .top) { Self.line.frame(height: 1) }
                }
            }

            HStack(spacing: Tokens.Spacing.tight) {
                Button("+ Row", action: onAddRow)
                    .disabled(block.cells.count - 1 >= NotepadRules.maxTableRows)
                Button("+ Column", action: onAddColumn)
                    .disabled((block.cells.first?.count ?? 0) >= NotepadRules.maxTableColumns)
            }
            .buttonStyle(.rpText)
            .padding(.horizontal, Tokens.Spacing.tight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Self.line.frame(height: 1) }
        }
        .background(Self.shape.fill(Tokens.Surface.card))
        .overlay { Self.shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .clipShape(Self.shape)
    }

    private func box(row: Int, column: Int) -> some View {
        TextField(row == 0 ? "Heading" : "", text: Binding(
            get: { block.cells.indices.contains(row) && block.cells[row].indices.contains(column) ? block.cells[row][column] : "" },
            set: { value in
                guard block.cells.indices.contains(row), block.cells[row].indices.contains(column) else { return }
                block.cells[row][column] = NotepadRules.clipped(value, to: NotepadRules.maxTableCellLength)
            }
        ))
        .textStyle(row == 0 ? Typography.rowTitle : Typography.detail)
        .tabularNumerals()
        .foregroundStyle(Tokens.Ink.primary)
        .padding(.horizontal, Tokens.Spacing.gap)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.minTap, alignment: .leading)
        // A plain 1 pt line: a Divider here would lie flat across the box, not stand at its edge.
        .overlay(alignment: .leading) {
            if column > 0 { Self.line.frame(width: 1) }
        }
        .accessibilityLabel(row == 0 ? "Heading \(column + 1)" : "Row \(row), \(headingText(column))")
    }

    private func headingText(_ column: Int) -> String {
        let heading = block.cells.first.flatMap { $0.indices.contains(column) ? $0[column] : nil } ?? ""
        return heading.isEmpty ? "column \(column + 1)" : heading
    }
}
