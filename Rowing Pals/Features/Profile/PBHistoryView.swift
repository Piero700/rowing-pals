//
//  PBHistoryView.swift
//  Rowing Pals
//

import Charts
import SwiftUI

/// Screen 10 — PB history, opened from any PB tile. Redesign phase
/// (docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 10, §3): a
/// summary card, a 3-button period control, a scrubbable line chart (drag
/// directly on the chart, a paired range slider, and prev/next buttons all
/// drive one shared "selected point" state), and a dated list of every
/// result below. Builds on the task-15 PB progression chart
/// (`PBHistoryViewModel`) — same reversed-y-axis-for-distance-tests
/// critical rule, same PB flagging — this is the richer, scrubbable
/// interaction model layered on top of that existing data.
///
/// Not built here, per the handoff's own warning: the prediction/estimate
/// card. It's an explicitly-flagged placeholder for an unbuilt algorithm,
/// not part of this screen's real content.
struct PBHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PBHistoryViewModel
    @State private var selectedID: UUID?
    /// Redesign phase B — per-device display preference, not synced to
    /// the profile. See DesignSystem/DistanceUnit.swift.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnit: DistanceUnit = .metres

    init(test: StandardTest) {
        _viewModel = State(initialValue: PBHistoryViewModel(test: test))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if viewModel.points.isEmpty {
                    emptyState
                } else {
                    PillSegmentedControl(options: PBHistoryViewModel.Period.allCases.map(\.label), selection: periodSelection)
                    summaryCard
                    scrubChart
                        .frame(height: 220)
                    rangeControls
                    resultList
                }

                Color.clear.frame(height: 40)
            }
            .padding(16)
        }
        .background(Tokens.Base.ground)
        .edgeSwipeToDismiss()
        .task {
            await viewModel.load()
            selectedID = viewModel.points.last?.id
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Text("\(viewModel.test.label) history")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.top, 40)
    }

    private var periodSelection: Binding<Int> {
        Binding(
            get: { viewModel.period.rawValue },
            set: {
                viewModel.period = PBHistoryViewModel.Period(rawValue: $0) ?? .all
                // The selected point may have fallen outside the new
                // window — fall back to the most recent point still shown.
                if selectedID == nil || !viewModel.points.contains(where: { $0.id == selectedID }) {
                    selectedID = viewModel.points.last?.id
                }
            }
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                Text("Couldn't load this chart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text(errorMessage)
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            } else {
                Text("No results yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
            }
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary card

    /// Current best, the date it was set, and a "+N faster/further" gain
    /// badge over the PB before it — per the handoff doc. No gain badge at
    /// all when there's nothing earlier to compare against.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CURRENT BEST")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(viewModel.currentBestLabel ?? "—")
                    .font(.system(size: 30, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                if let dateLabel = currentBestDateLabel {
                    Text(dateLabel)
                        .textStyle(Typography.bodySecondary)
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            if let gainLabel {
                Text(gainLabel)
                    .font(.system(size: 12.5, weight: .semibold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.records)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 22)
    }

    private var currentBestDateLabel: String? {
        guard let best = viewModel.allPoints.last(where: \.isPB) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: best.date)
    }

    /// "+N faster" for a distance test (smaller value is better), "+Nm
    /// further" for a duration test (larger value is better) — the gap
    /// between the current PB and the one immediately before it.
    private var gainLabel: String? {
        guard
            let current = viewModel.allPoints.last(where: \.isPB)?.value,
            let previous = viewModel.previousBestValue
        else { return nil }

        if viewModel.test.isDurationBased {
            let gainM = Int(current - previous)
            guard gainM > 0 else { return nil }
            return "+\(gainM.formattedDistance(unit: distanceUnit)) further"
        } else {
            let gainMs = Int(previous - current)
            guard gainMs > 0 else { return nil }
            return "+\(gainMs.formattedDurationMs) faster"
        }
    }

    // MARK: - Scrubbable chart

    private var selectedPoint: PBHistoryViewModel.Point? {
        viewModel.points.first { $0.id == selectedID }
    }

    /// See `PBHistoryViewModel`'s doc comment on the reversed-axis rule for
    /// distance tests — unchanged from the original PB progression chart.
    private var yDomain: [Double] {
        let values = viewModel.points.map(\.value)
        guard let dataMin = values.min(), let dataMax = values.max() else { return [0, 1] }

        if viewModel.test.isDurationBased {
            let padding = max((dataMax - dataMin) * 0.15, 200)
            return [max(0, dataMin - padding), dataMax + padding]
        } else {
            let lowerPadding: Double = 2 * 60 * 1000
            let upperPadding = max((dataMax - dataMin) * 0.15, 5_000)
            return [dataMax + upperPadding, max(0, dataMin - lowerPadding)]
        }
    }

    private var scrubChart: some View {
        Chart(viewModel.points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(Tokens.Accent.brand)
                .interpolationMethod(.monotone)
            AreaMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(Tokens.Accent.brand.opacity(0.08))
                .interpolationMethod(.monotone)

            let isSelected = point.id == selectedID
            PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(isSelected ? Tokens.Accent.records : (point.isPB ? Tokens.Accent.records.opacity(0.6) : Tokens.Accent.brand))
                .symbolSize(isSelected ? 160 : (point.isPB ? 80 : 50))

            if let selectedPoint, isSelected {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(Tokens.Ink.primary.opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(PBHistoryViewModel.format(raw, isDurationBased: viewModel.test.isDurationBased, unit: distanceUnit))
                            .tabularNumerals()
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                selectNearestPoint(to: drag.location, proxy: proxy, geometry: geometry)
                            }
                    )
            }
        }
    }

    /// Maps a drag location to the nearest plotted date — the shared
    /// mechanism behind chart-scrubbing, the range slider, the prev/next
    /// buttons, and tapping a list row, all of which just move `selectedID`.
    private func selectNearestPoint(to location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let origin = geometry[plotFrameAnchor].origin
        let xInPlot = location.x - origin.x
        guard let date: Date = proxy.value(atX: xInPlot) else { return }
        guard let nearest = viewModel.points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else { return }
        selectedID = nearest.id
    }

    // MARK: - Range slider + prev/next

    private var selectedIndex: Int {
        guard let selectedID, let index = viewModel.points.firstIndex(where: { $0.id == selectedID }) else {
            return max(viewModel.points.count - 1, 0)
        }
        return index
    }

    private var rangeControls: some View {
        HStack(spacing: 10) {
            stepButton(systemImage: "chevron.left", enabled: selectedIndex > 0) {
                move(by: -1)
            }
            Slider(
                value: Binding(
                    get: { Double(selectedIndex) },
                    set: { newValue in
                        let clamped = min(max(Int(newValue.rounded()), 0), max(viewModel.points.count - 1, 0))
                        guard viewModel.points.indices.contains(clamped) else { return }
                        selectedID = viewModel.points[clamped].id
                    }
                ),
                in: 0...Double(max(viewModel.points.count - 1, 0)),
                step: 1
            )
            .tint(Tokens.Accent.brand)
            stepButton(systemImage: "chevron.right", enabled: selectedIndex < viewModel.points.count - 1) {
                move(by: 1)
            }
        }
    }

    private func move(by delta: Int) {
        let target = selectedIndex + delta
        guard viewModel.points.indices.contains(target) else { return }
        selectedID = viewModel.points[target].id
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? Tokens.Ink.primary : Tokens.Ink.secondary.opacity(0.4))
                .frame(width: 30, height: 30)
                .background {
                    Circle().fill(Tokens.Ink.primary.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Result list

    /// Most recent first, each tappable to jump the chart/slider to it —
    /// per the handoff doc. `viewModel.points` is chronological ascending
    /// (the chart's own order), so this just reverses for display.
    private var resultList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EVERY RESULT")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)

            ForEach(Array(viewModel.points.reversed())) { point in
                resultRow(point)
                    .onTapGesture { selectedID = point.id }
            }
        }
    }

    private func resultRow(_ point: PBHistoryViewModel.Point) -> some View {
        let isSelected = point.id == selectedID
        let isCurrentBest = point.id == viewModel.allPoints.last(where: \.isPB)?.id
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatter.string(from: point.date))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                if isCurrentBest {
                    Text("Current PB")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.Accent.records)
                } else if point.isPB {
                    Text("Personal best")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.Ink.secondary)
                }
            }
            Spacer()
            Text(PBHistoryViewModel.format(point.value, isDurationBased: viewModel.test.isDurationBased, unit: distanceUnit))
                .font(.system(size: 15, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Tokens.Accent.brand.opacity(0.12) : Tokens.Ink.primary.opacity(0.05))
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Tokens.Accent.brand.opacity(0.4), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    PBHistoryView(test: StandardTest.all[2])
}
