//
//  BestsEditor.swift
//  Rowing Pals
//

import SwiftUI

/// The "Your bests" form (decision 64), shared by sign-up and Settings: the 2k and 5k first,
/// then any other best the rower adds — a distance and its time, or a time and the metres
/// covered. Times are typed like every time in the app (decision 56). Saving is the caller's.
struct BestsEditor: View {
    @Binding var rows: [BestRow]

    private enum Field: Hashable {
        case time(UUID), metres(UUID)
    }

    @FocusState private var focus: Field?
    @State private var isChoosingKind = false

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let fieldShape = RoundedRectangle(cornerRadius: Tokens.Radius.input, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            ForEach($rows) { $row in
                card($row)
            }
            Button {
                isChoosingKind = true
            } label: {
                Label("Add another best", icon: .plus)
            }
            .buttonStyle(.rpGlass)
            .padding(.top, Tokens.Spacing.tight)
        }
        .confirmationDialog("Add a best", isPresented: $isChoosingKind, titleVisibility: .visible) {
            Button("A distance, e.g. 1k in 3:15") { add(.distance) }
            Button("A time, e.g. 20 minutes, 5,400m") { add(.time) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func add(_ kind: BestRow.Kind) {
        let row = BestRow(kind: kind)
        rows.append(row)
        focus = kind == .distance ? .metres(row.id) : .time(row.id)
    }

    private func card(_ row: Binding<BestRow>) -> some View {
        let value = row.wrappedValue
        return VStack(alignment: .leading, spacing: Tokens.Spacing.tight) {
            HStack {
                Text(value.title)
                    .textStyle(Typography.rowTitle)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer(minLength: 0)
                if value.fixedDistanceM == nil {
                    Button {
                        rows.removeAll { $0.id == value.id }
                    } label: {
                        RPIconView(icon: .close, size: Tokens.Icon.small)
                            .textStyle(Typography.pill)
                            .foregroundStyle(Tokens.Ink.secondary)
                            .frame(width: Tokens.Size.minTap, height: Tokens.Size.minTap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconPressStyle())
                    .accessibilityLabel("Remove this best")
                }
            }
            HStack(spacing: Tokens.Spacing.tight) {
                if value.fixedDistanceM != nil {
                    timeField(row, label: "Your time", placeholder: "0:00.0")
                } else if value.kind == .distance {
                    metresField(row, label: "Distance")
                    timeField(row, label: "Your time", placeholder: "0:00.0")
                } else {
                    timeField(row, label: "How long", placeholder: "20:00")
                    metresField(row, label: "Metres covered")
                }
            }
            if let hint = value.missingHint {
                Text(hint)
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            } else if value.isInvalid {
                Text("Check this one: it should be 100m or more, with a split between 1:00 and 5:00 /500m.")
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.System.error)
            } else if let parsed = value.parsed {
                let split = Int((Double(parsed.timeMs) / (Double(parsed.distanceM) / 500)).rounded())
                Text("\(split.formattedDurationMs) /500m")
                    .textStyle(Typography.statLabel)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .padding(Tokens.Spacing.card)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.fieldLabel)
            .foregroundStyle(Tokens.Ink.secondary)
    }

    private func timeField(_ row: Binding<BestRow>, label text: String, placeholder: String) -> some View {
        let value = row.wrappedValue
        return VStack(alignment: .leading, spacing: 6) {
            label(text)
            DurationTextField(placeholder: placeholder, text: row.timeText,
                              allowsTenths: value.kind == .distance, focus: $focus, field: .time(value.id))
                .textStyle(Typography.bodyV3)
                .tabularNumerals()
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.input, alignment: .leading)
                .background(Self.fieldShape.fill(Tokens.Base.ground))
                .overlay {
                    Self.fieldShape.strokeBorder(value.isInvalid ? Tokens.System.error : Tokens.Surface.line, lineWidth: 1)
                }
        }
    }

    private func metresField(_ row: Binding<BestRow>, label text: String) -> some View {
        let value = row.wrappedValue
        return VStack(alignment: .leading, spacing: 6) {
            label(text)
            HStack(spacing: 4) {
                TextField("metres", text: row.metresText)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .metres(value.id))
                    .onChange(of: value.metresText) { _, new in
                        let clean = String(new.filter(\.isWholeNumber).prefix(6))
                        if clean != new { row.wrappedValue.metresText = clean }
                    }
                Text("m")
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .textStyle(Typography.bodyV3)
            .tabularNumerals()
            .foregroundStyle(Tokens.Ink.primary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.input, alignment: .leading)
            .background(Self.fieldShape.fill(Tokens.Base.ground))
            .overlay {
                Self.fieldShape.strokeBorder(value.isInvalid ? Tokens.System.error : Tokens.Surface.line, lineWidth: 1)
            }
        }
    }
}
