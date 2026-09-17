//
//  PBProgressionView.swift
//  Rowing Pals
//

import Charts
import SwiftUI

/// A PB tile's drill-down (design brief: "the chart is the natural
/// drill-down of the tile, rather than a separate section"). Every
/// attempt at this distance, gold where it was a PB at the time, cyan
/// otherwise.
///
/// Critical (design brief, task 15): on a distance test, faster is a
/// *smaller* millisecond value, but every reader instinctively reads "up"
/// as better — the y-axis is reversed so the line still climbs as the
/// rower improves. A duration test reads the other way already (a bigger
/// metres number is better), so it isn't reversed.
struct PBProgressionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PBProgressionViewModel

    init(test: StandardTest) {
        _viewModel = State(initialValue: PBProgressionViewModel(test: test))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if viewModel.points.isEmpty {
                    emptyState
                } else {
                    chart
                        .frame(height: 260)
                        .padding(.top, 8)

                    if let label = viewModel.currentBestLabel {
                        HStack(spacing: 6) {
                            Circle().fill(Tokens.Accent.records).frame(width: 8, height: 8)
                            Text("Current PB: \(label)")
                                .textStyle(Typography.bodySecondary)
                                .tabularNumerals()
                                .foregroundStyle(Tokens.Ink.primary)
                        }
                    }
                }

                Color.clear.frame(height: 40)
            }
            .padding(16)
        }
        .background(Tokens.Base.ground)
        .edgeSwipeToDismiss()
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Text("\(viewModel.test.label) progression")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.top, 40)
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

    /// A `ClosedRange` can't express a reversed axis — its init traps if
    /// the lower bound exceeds the upper one — so this is a two-element
    /// array instead: Swift Charts treats `[max, min]` as an explicit,
    /// reversed domain. Zoomed to the data's own range (plus a little
    /// headroom) rather than `.automatic`'s default of padding out from
    /// zero, which — for times a couple of minutes apart clustered around
    /// 6-7 minutes — left the whole meaningful range squeezed into a few
    /// pixels at the top of the chart.
    private var yDomain: [Double] {
        let values = viewModel.points.map(\.value)
        guard let dataMin = values.min(), let dataMax = values.max() else { return [0, 1] }

        if viewModel.test.isDurationBased {
            let padding = max((dataMax - dataMin) * 0.15, 200)
            return [max(0, dataMin - padding), dataMax + padding]
        } else {
            let lowerPadding: Double = 2 * 60 * 1000 // 2 minutes, ahead of the fastest time
            let upperPadding = max((dataMax - dataMin) * 0.15, 5_000)
            return [dataMax + upperPadding, max(0, dataMin - lowerPadding)] // max first: reversed
        }
    }

    private var chart: some View {
        Chart(viewModel.points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(Tokens.Accent.brand)
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(point.isPB ? Tokens.Accent.records : Tokens.Accent.brand)
                .symbolSize(point.isPB ? 90 : 50)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(PBProgressionViewModel.format(raw, isDurationBased: viewModel.test.isDurationBased))
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
    }
}

#Preview {
    PBProgressionView(test: StandardTest.all[2])
}
