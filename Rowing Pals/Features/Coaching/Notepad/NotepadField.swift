//
//  NotepadField.swift
//  Rowing Pals
//

import Foundation

/// The entry bar's fields, for moving the keyboard between them (decision 96).
enum NotepadField: Hashable {
    /// The split or the time, typed with `DurationTextField`.
    case duration
    /// The metres, for a time piece.
    case metres
    case rate
}
