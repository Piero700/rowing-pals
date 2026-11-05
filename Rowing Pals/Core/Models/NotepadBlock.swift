//
//  NotepadBlock.swift
//  Rowing Pals
//

import Foundation

/// One block a coach added to a notepad page (decision 96): a text box, or a table with a title,
/// a heading row and rows under it. Stored in `coach_notepads.blocks` as JSON with these keys.
/// The Scores table isn't a block: every page has it, above the blocks.
nonisolated struct NotepadBlock: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case text
        case table
    }

    var id: UUID
    var kind: Kind
    /// A text box's words.
    var text: String
    /// A table's name.
    var title: String
    /// A table's boxes, row by row; the first row is its headings.
    var cells: [[String]]

    init(id: UUID = UUID(), kind: Kind, text: String = "", title: String = "", cells: [[String]] = []) {
        self.id = id
        self.kind = kind
        self.text = text
        self.title = title
        self.cells = cells
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, text, title, cells
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        kind = try c.decode(Kind.self, forKey: .kind)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        cells = try c.decodeIfPresent([[String]].self, forKey: .cells) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        switch kind {
        case .text:
            try c.encode(text, forKey: .text)
        case .table:
            try c.encode(title, forKey: .title)
            try c.encode(cells, forKey: .cells)
        }
    }
}
