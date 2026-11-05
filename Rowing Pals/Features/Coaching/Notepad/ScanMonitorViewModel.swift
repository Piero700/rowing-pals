//
//  ScanMonitorViewModel.swift
//  Rowing Pals
//

import Foundation
import UIKit

/// Scanning one rower's monitor into a workout's notepad (CoachNotepadScan, decision 96, NP2):
/// each photo is read on the phone, its results table joined onto the screens before it, and the
/// pieces filled into the rower's row as `scanned` scores. The photo lives only in memory while
/// Vision reads it: it is never written to disk, Storage or the photo library.
@Observable
final class ScanMonitorViewModel {
    let workoutId: UUID
    let rowerId: UUID

    var rowerName = ""
    var workoutTitle = ""
    /// How many pieces the workout has (every rep of every piece).
    var repCount = 1
    /// The photos read so far.
    var screens = 0
    /// Every interval read so far, each kept once; for a one-piece workout, the summary row.
    var rows: [MonitorRow] = []
    /// Which of `rows` came from the last photo.
    var newIndices: Set<Int> = []
    /// The pieces the last photo shared with the one before (counting from 1).
    var overlap: ClosedRange<Int>?
    var isCapturing = true
    var isReading = false
    var isFilling = false
    var errorMessage: String?

    init(workoutId: UUID, rowerId: UUID) {
        self.workoutId = workoutId
        self.rowerId = rowerId
    }

    @MainActor
    func load() async {
        do {
            async let workoutTask = WorkoutService.workout(workoutId)
            async let rosterTask = CoachingService.roster()
            let (workout, roster) = try await (workoutTask, rosterTask)
            workoutTitle = workout.title
            repCount = NotepadRules.reps(workout.pieces).count
            rowerName = roster.rowers.first { $0.id == rowerId }?.displayName ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reading a photo

    /// Reads one photo and joins its pieces onto what's been read. The image is made here and goes
    /// when this returns: nothing keeps it.
    @MainActor
    func read(_ photo: Data) async {
        isReading = true
        defer { isReading = false }
        do {
            guard let image = UIImage(data: photo) else { throw OCRError.invalidImage }
            let table = MonitorParser.intervalRows(try await OCRService.recognizeText(in: image))
            guard let summary = table.first, summary.isSummary else {
                errorMessage = "Couldn’t find the results table on that photo. Fit the monitor’s results inside the frame and try again."
                return
            }
            if repCount == 1 {
                rows = [summary]
                newIndices = [0]
                overlap = nil
            } else {
                let joined = NotepadRules.join(rows, table)
                guard !joined.rows.isEmpty else {
                    errorMessage = "No pieces showed on that photo. Scroll the monitor to the list of pieces and try again."
                    return
                }
                rows = joined.rows
                newIndices = joined.newIndices
                overlap = joined.overlap
            }
            screens += 1
            errorMessage = nil
            isCapturing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - What the screen says

    var readCount: Int { min(rows.count, repCount) }
    var isDone: Bool { readCount >= repCount }
    var firstName: String { rowerName.split(separator: " ").first.map(String.init) ?? rowerName }

    /// "Ollie Hart · 20 × 250m".
    var title: String { [rowerName, workoutTitle].filter { !$0.isEmpty }.joined(separator: " · ") }

    /// "8 of 20 read".
    var countLabel: String { "\(readCount) of \(repCount) read" }

    var finderLabel: String { screens == 0 ? "MONITOR · RESULTS SCREEN" : "MONITOR · NEXT PAGE OF RESULTS" }

    var finderHelp: String {
        screens == 0
            ? "Fit the monitor’s results inside the frame. Only the numbers are kept: the photo is deleted once it’s read."
            : "Scroll the monitor down to the next pieces, then take another photo. Overlap is fine."
    }

    var banner: String { "Read from screen \(screens). The photo has been deleted, only these numbers are kept." }

    /// The line under the pieces: what the overlap did, and what's left.
    var footnote: String {
        var parts: [String] = []
        if let overlap {
            let pieces = overlap.count == 1 ? "Piece \(overlap.lowerBound) was" : "Pieces \(overlap.lowerBound)–\(overlap.upperBound) were"
            parts.append("\(pieces) on both screens, so \(overlap.count == 1 ? "it’s" : "they’re") kept once.")
        }
        if isDone {
            parts.append(repCount == 1
                ? "That’s the piece. Tap a number on the page to fix it."
                : "All \(repCount) pieces are in. Tap a number on the page to fix it.")
            if rows.count > repCount {
                parts.append("The workout has \(repCount), so only the first \(repCount) are kept.")
            }
        } else {
            let left = repCount - readCount
            parts.append("Highlighted rows are new. \(left) \(left == 1 ? "piece" : "pieces") still to read.")
        }
        return parts.joined(separator: " ")
    }

    var fillLabel: String {
        let name = firstName.isEmpty ? "the" : "\(firstName)’s"
        if isDone { return "Fill \(name) row" }
        return "Fill \(name) row with \(readCount) \(readCount == 1 ? "piece" : "pieces")"
    }

    // MARK: - Filling the row

    /// Saves every piece read as the rower's scores on the page. True when they all saved.
    @MainActor
    func fill() async -> Bool {
        isFilling = true
        defer { isFilling = false }
        let scores = NotepadRules.scannedScores(
            rows: repCount == 1 ? [] : rows, summary: repCount == 1 ? rows.first : nil,
            repCount: repCount, workoutId: workoutId, rowerId: rowerId
        )
        do {
            for score in scores {
                try await NotepadService.saveScore(score)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
