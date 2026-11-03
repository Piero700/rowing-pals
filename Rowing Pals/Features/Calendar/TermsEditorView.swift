//
//  TermsEditorView.swift
//  Rowing Pals
//

import SwiftUI

/// The club's term dates (decision 39), from Attendance totals' Edit dates: each term's name, first
/// and last day; add a term, change one, or swipe one left to delete it (user, 2026-11-03). "This
/// term" counts from the start of the term holding today.
struct TermsEditorView: View {
    struct Draft: Identifiable, Equatable {
        let id: UUID
        var termId: UUID?
        var name: String
        var startsOn: Date
        var endsOn: Date
    }

    @State private var drafts: [Draft] = []
    @State private var saved: [Draft] = []
    @State private var isSaving = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FormFootnote("Attendance’s This term counts from the first day of the term holding today.")
                ForEach($drafts) { $draft in
                    let id = draft.id
                    termCard($draft)
                        // Gone from the list now; Save terms deletes it from the club.
                        .swipeToDelete {
                            withAnimation(.snappy) { drafts.removeAll { $0.id == id } }
                            return true
                        }
                        .padding(.top, Tokens.Spacing.loose)
                }
                Button {
                    drafts.append(newDraft())
                } label: {
                    Label("Add a term", icon: .plus)
                }
                .buttonStyle(.rpGlass)
                .padding(.top, Tokens.Spacing.loose)

                if let errorMessage {
                    Text(errorMessage)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .padding(.horizontal, 4)
                        .padding(.top, Tokens.Spacing.loose)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(Tokens.Ink.onBrand)
                    } else {
                        Text("Save terms")
                    }
                }
                .buttonStyle(.rpPrimary)
                .disabled(isSaving || problem != nil)
                .padding(.top, Tokens.Spacing.group)
                if let problem {
                    FormFootnote(problem)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { ScreenHeader(title: "Term dates") { dismiss() } }
        .background(Tokens.Base.ground)
        .dismissesKeyboardOnTap()
        .task { await load() }
    }

    private var problem: String? {
        if drafts.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) { return "Give every term a name." }
        if drafts.contains(where: { $0.endsOn < $0.startsOn }) { return "A term has to end on or after its first day." }
        return nil
    }

    private func termCard(_ draft: Binding<Draft>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Autumn", text: draft.name)
                .textStyle(Typography.rowTitle)
                .foregroundStyle(Tokens.Ink.primary)
            HStack(spacing: Tokens.Spacing.loose) {
                VStack(alignment: .leading, spacing: 0) {
                    FormLabel("First day")
                    DatePicker("First day", selection: draft.startsOn, displayedComponents: .date)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    FormLabel("Last day")
                    DatePicker("Last day", selection: draft.endsOn, displayedComponents: .date)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, Tokens.Spacing.loose)
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func newDraft() -> Draft {
        let calendar = Calendar.current
        let start = drafts.last.flatMap { calendar.date(byAdding: .day, value: 1, to: $0.endsOn) } ?? calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .weekOfYear, value: 10, to: start) ?? start
        return Draft(id: UUID(), termId: nil, name: "", startsOn: start, endsOn: end)
    }

    private func load() async {
        guard !hasLoaded else { return }
        do {
            let calendar = Calendar.current
            let terms = try await CalendarService.terms()
            drafts = terms.compactMap { term in
                guard let start = WorkoutRules.day(term.startsOn, calendar: calendar),
                      let end = WorkoutRules.day(term.endsOn, calendar: calendar) else { return nil }
                return Draft(id: term.id, termId: term.id, name: term.name, startsOn: start, endsOn: end)
            }
            saved = drafts
            hasLoaded = true
        } catch {
            errorMessage = "Couldn’t load the terms. \(error.localizedDescription)"
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let kept = Set(drafts.compactMap(\.termId))
            for old in saved where old.termId.map({ !kept.contains($0) }) ?? false {
                if let id = old.termId { try await CalendarService.deleteTerm(id) }
            }
            for draft in drafts where draft != saved.first(where: { $0.id == draft.id }) {
                try await CalendarService.saveTerm(id: draft.termId, name: draft.name, startsOn: draft.startsOn, endsOn: draft.endsOn)
            }
            dismiss()
        } catch {
            errorMessage = "Couldn’t save the terms. \(error.localizedDescription)"
        }
    }
}
