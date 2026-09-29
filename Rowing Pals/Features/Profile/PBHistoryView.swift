//
//  PBHistoryView.swift
//  Rowing Pals
//

import Charts
import SwiftUI

/// Screen 10 — PB history, to v3 §10 (`docs/design/v3/RP Screen.dc.html`): "PB history · 2K"
/// header; the rower's name; on your own 2k/5k, the estimate card (a dash until the user's
/// algorithm arrives — decision 2); the current personal best with how much faster (or
/// further) it is than the first; 3 months / 6 months / All time; the "PB progression" chart
/// card — results that were a PB when set, "Lower is faster" (slower times higher up, as v3
/// draws it), a panel for the chosen result, prev/next and a slider; then "Personal best
/// history", newest first. Tapping the chart, sliding, stepping or tapping a row all move the
/// same chosen result.
struct PBHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PBHistoryViewModel
    @State private var selectedID: UUID?
    private let isOwnHistory: Bool

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    init(test: StandardTest, userId: UUID? = nil) {
        _viewModel = State(initialValue: PBHistoryViewModel(test: test, userId: userId))
        isOwnHistory = userId == nil
    }

    private var test: StandardTest { viewModel.test }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let name = viewModel.rowerName {
                    Text(name)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                        .padding(.bottom, 16)
                }

                // v3 draws estimates for the 2k and 5k, on your own history only.
                if isOwnHistory && ["2k", "5k"].contains(test.key) {
                    EstimateCard(label: "\(test.label) · Estimated today")
                        .padding(.bottom, 14)
                }

                if let current = viewModel.currentPB {
                    currentBestCard(current)
                    PillSegmentedControl(options: PBHistoryViewModel.Period.allCases.map(\.label), selection: periodSelection)
                        .padding(.vertical, 16)
                    if viewModel.pbPoints.isEmpty {
                        message("No personal bests in this period.")
                    } else {
                        chartCard
                        sectionTitle("Personal best history")
                        historyList
                    }
                } else if !viewModel.isLoading {
                    message(viewModel.errorMessage.map { "Couldn't load this history. \($0)" } ?? "No \(test.label) results yet.")
                }
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: "PB history · \(test.shortTitle)") { dismiss() }
        }
        .background(Tokens.Base.ground)
        .edgeSwipeToDismiss()
        .task {
            await viewModel.load()
            selectedID = viewModel.pbPoints.last?.id
        }
    }

    private var periodSelection: Binding<Int> {
        Binding(
            get: { viewModel.period.rawValue },
            set: {
                viewModel.period = PBHistoryViewModel.Period(rawValue: $0) ?? .all
                // The chosen result may have fallen outside the new window.
                if !viewModel.pbPoints.contains(where: { $0.id == selectedID }) {
                    selectedID = viewModel.pbPoints.last?.id
                }
            }
        )
    }

    private func format(_ value: Double) -> String {
        PBHistoryViewModel.format(value, isDurationBased: test.isDurationBased)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.meta)
            .foregroundStyle(Tokens.Ink.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Self.cardShape.fill(Tokens.Surface.card))
            .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.sectionTitle)
            .foregroundStyle(Tokens.Ink.secondary)
            .padding(.horizontal, 2)
            .padding(.top, Tokens.Spacing.sectionTop)
            .padding(.bottom, Tokens.Spacing.sectionBottom)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Current personal best

    /// Label, the PB in the records colour, its date; on the right, the gain since the first PB.
    private func currentBestCard(_ current: PBHistoryViewModel.Point) -> some View {
        HStack(spacing: Tokens.Spacing.gap) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Current personal best")
                    .textStyle(Typography.overline)
                    .foregroundStyle(Tokens.Ink.secondary)
                Text(format(current.value))
                    .textStyle(Typography.pbValue)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.records)
                    .padding(.vertical, 8)
                Text(Self.dateFormatter.string(from: current.date))
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer(minLength: 0)
            if let gain = viewModel.gainSinceFirstPB, gain > 0 {
                Text(test.isDurationBased ? "\(Int(gain).formattedMetres) further" : "\(Int(gain).formattedDurationMs) faster")
                    .textStyle(Typography.pill)
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Accent.records)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Tokens.Accent.recordsSoft))
            }
        }
        .padding(20)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    // MARK: - PB progression chart card

    private var selectedPoint: PBHistoryViewModel.Point? {
        viewModel.pbPoints.first { $0.id == selectedID } ?? viewModel.pbPoints.last
    }

    private var selectedIndex: Int {
        guard let selectedPoint, let index = viewModel.pbPoints.firstIndex(where: { $0.id == selectedPoint.id }) else {
            return max(viewModel.pbPoints.count - 1, 0)
        }
        return index
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PB progression")
                    .textStyle(Typography.cardTitle)
                    .foregroundStyle(Tokens.Ink.primary)
                Spacer()
                Text(test.isDurationBased ? "Higher is further" : "Lower is faster")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            .padding(.horizontal, 7)
            Text(test.isDurationBased ? "Distance · metres" : "Time · min:sec")
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.secondary)
                .padding(.horizontal, 7)
                .padding(.top, Tokens.Spacing.loose)

            chart
                .frame(height: 230)
                .padding(.top, 18)
                .padding(.horizontal, 7)

            if let selectedPoint {
                selectedPanel(selectedPoint)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                    .padding(.bottom, Tokens.Spacing.gap)
            }
            scrubber
                .padding(.horizontal, 6)
            Text("Tap the line or slide to explore each result.")
                .textStyle(Typography.statLabel)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 3)
        }
        .padding(.top, 16)
        .padding(.horizontal, Tokens.Spacing.gap)
        .padding(.bottom, Tokens.Spacing.gap)
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    /// Bigger values higher up, as v3 draws it — so a faster 2k sits lower ("Lower is
    /// faster") and a longer 30-minute piece higher. Padded like v3: generous room under a
    /// time chart's best, a little above its slowest.
    private var yDomain: ClosedRange<Double> {
        let values = viewModel.pbPoints.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let range = high - low
        if test.isDurationBased {
            return max(0, low - max(range * 0.25, 200))...(high + max(range * 0.5, 400))
        }
        return max(0, low - 120_000)...(high + max(range * 0.25, 5_000))
    }

    /// Five dashed grid lines from top to bottom, as v3's chart.
    private var gridValues: [Double] {
        let domain = yDomain
        return (0...4).map { domain.upperBound - (domain.upperBound - domain.lowerBound) * Double($0) / 4 }
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = viewModel.pbPoints.first?.date, let last = viewModel.pbPoints.last?.date, first < last else {
            let only = viewModel.pbPoints.first?.date ?? Date()
            return only.addingTimeInterval(-86_400 * 15)...only.addingTimeInterval(86_400 * 15)
        }
        return first...last
    }

    private var chart: some View {
        Chart {
            ForEach(viewModel.pbPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", yDomain.lowerBound),
                    yEnd: .value("Result", point.value)
                )
                .foregroundStyle(Tokens.Accent.brandSoft)
                LineMark(x: .value("Date", point.date), y: .value("Result", point.value))
                    .foregroundStyle(Tokens.Accent.brand)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            if let selectedPoint {
                RuleMark(x: .value("Chosen", selectedPoint.date))
                    .foregroundStyle(Tokens.Accent.records)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            ForEach(viewModel.pbPoints) { point in
                let isSelected = point.id == selectedPoint?.id
                PointMark(x: .value("Date", point.date), y: .value("Result", point.value))
                    .symbol {
                        Circle()
                            .fill(isSelected ? Tokens.Accent.records : Tokens.Surface.card)
                            .overlay { Circle().strokeBorder(Tokens.Accent.brand, lineWidth: 2) }
                            .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: gridValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .foregroundStyle(Tokens.Surface.line)
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(format(raw))
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: [xDomain.lowerBound, xDomain.upperBound]) { value in
                AxisValueLabel(anchor: value.index == 0 ? .topLeading : .topTrailing) {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).year(.twoDigits))
                            .font(.system(size: 13))
                            .foregroundStyle(Tokens.Ink.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    // A tap, not a drag: a drag here would stop the page scrolling over the
                    // chart. Sliding through results is the slider's job ("Tap the line or
                    // slide to explore each result").
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { tap in select(nearest: tap.location, proxy: proxy, geometry: geometry) }
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("PB progression chart")
        .accessibilityValue(selectedPoint.map { "\(Self.dateFormatter.string(from: $0.date)), \(format($0.value))" } ?? "")
    }

    /// Tap on the chart: the result nearest in time becomes the chosen one.
    private func select(nearest location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = location.x - geometry[plotFrame].origin.x
        guard let date: Date = proxy.value(atX: x) else { return }
        selectedID = viewModel.pbPoints.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }?.id
    }

    /// Raised panel: the chosen result's date and whether it is the latest PB; its value.
    private func selectedPanel(_ point: PBHistoryViewModel.Point) -> some View {
        let isLatest = point.id == viewModel.currentPB?.id
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: point.date))
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Ink.primary)
                Text(isLatest ? "Latest personal best" : "Personal best")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text(format(point.value))
                .textStyle(Typography.selectedValue)
                .tabularNumerals()
                .foregroundStyle(Tokens.Accent.brand)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, Tokens.Spacing.loose)
        .frame(minHeight: 74)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.panel, style: .continuous).fill(Tokens.Surface.raised))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Prev / slider / next

    private var scrubber: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            stepButton("chevron.left", label: "Previous", enabled: selectedIndex > 0) { move(by: -1) }
            track
            stepButton("chevron.right", label: "Next", enabled: selectedIndex < viewModel.pbPoints.count - 1) { move(by: 1) }
        }
    }

    private func stepButton(_ systemImage: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        GlassIconButton(systemImage: systemImage, accessibilityLabel: label, action: action)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.35)
    }

    /// v3's slider: an 8 pt glass track and a 30 × 22 glass thumb, stepping result by result.
    private var track: some View {
        let count = viewModel.pbPoints.count
        return GeometryReader { geometry in
            let thumbWidth: CGFloat = 30
            let travel = max(geometry.size.width - thumbWidth, 0)
            let fraction = count > 1 ? CGFloat(selectedIndex) / CGFloat(count - 1) : 1
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Tokens.Glass.fill)
                    .overlay { Capsule().strokeBorder(Tokens.Glass.edge, lineWidth: 1) }
                    .frame(height: 8)
                Capsule()
                    .fill(Tokens.Glass.fillStrong)
                    .overlay { Capsule().strokeBorder(Tokens.Glass.edge, lineWidth: 1) }
                    .shadow(color: Tokens.Glass.shadow, radius: 5, y: 3)
                    .frame(width: thumbWidth, height: 22)
                    .offset(x: travel * fraction)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    guard count > 1, travel > 0 else { return }
                    let position = min(max((drag.location.x - thumbWidth / 2) / travel, 0), 1)
                    let index = Int((position * CGFloat(count - 1)).rounded())
                    selectedID = viewModel.pbPoints[index].id
                }
            )
        }
        .frame(height: Tokens.Size.minTap)
        .accessibilityElement()
        .accessibilityLabel("Result")
        .accessibilityValue(selectedPoint.map { "\(Self.dateFormatter.string(from: $0.date)), \(format($0.value))" } ?? "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(by: 1)
            case .decrement: move(by: -1)
            @unknown default: break
            }
        }
    }

    private func move(by delta: Int) {
        let target = selectedIndex + delta
        guard viewModel.pbPoints.indices.contains(target) else { return }
        selectedID = viewModel.pbPoints[target].id
    }

    // MARK: - Personal best history

    /// One card, newest first; the current PB highlighted. Tapping a row chooses it above.
    private var historyList: some View {
        let rows = Array(viewModel.pbPoints.reversed())
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, point in
                historyRow(point)
                if index < rows.count - 1 {
                    Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                }
            }
        }
        .background(Self.cardShape.fill(Tokens.Surface.card))
        .clipShape(Self.cardShape)
        .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
    }

    private func historyRow(_ point: PBHistoryViewModel.Point) -> some View {
        let isCurrent = point.id == viewModel.currentPB?.id
        return HStack(spacing: Tokens.Spacing.gap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: point.date))
                    .textStyle(Typography.detail)
                    .foregroundStyle(isCurrent ? Tokens.Accent.brand : Tokens.Ink.primary)
                Text(isCurrent ? "Current PB" : "Personal best")
                    .textStyle(Typography.statLabel)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text(format(point.value))
                .textStyle(Typography.rankValue)
                .tabularNumerals()
                .foregroundStyle(isCurrent ? Tokens.Accent.brand : Tokens.Ink.primary)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
        .frame(minHeight: 68)
        .background(isCurrent ? Tokens.Accent.brandSoft : .clear)
        .asButton { selectedID = point.id }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PBHistoryView(test: StandardTest.all[2])
}
