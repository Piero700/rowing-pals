//
//  ReviewSheetView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 4 — session review. Recomputing totals from segments, editable
/// fields, and the real post write arrive with task 10; this is the static
/// layout with mock values.
struct ReviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""

    private struct MockSegment {
        let tag: String
        let dist: String
        let time: String
        let split: String
        let rate: String
        let lowConfidence: Bool
    }

    private let segments = [
        MockSegment(tag: "WARMUP", dist: "2,000m", time: "8:33.2", split: "2:08.3", rate: "r18", lowConfidence: false),
        MockSegment(tag: "MAIN", dist: "12,000m", time: "47:28.8", split: "1:58.7", rate: "r20", lowConfidence: true),
        MockSegment(tag: "COOLDOWN", dist: "2,000m", time: "8:48.0", split: "2:12.0", rate: "r17", lowConfidence: false)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Check your numbers")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Tokens.Ink.primary)

                totalCard

                VStack(spacing: 8) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        segmentRow(segment)
                    }
                }

                Text("+ Add another photo")
                    .textStyle(Typography.body)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Tokens.Ink.primary.opacity(0.05))
                    }

                testDetectedBanner

                HStack(spacing: 10) {
                    TextField("Add a caption…", text: $caption)
                        .textStyle(Typography.body)
                        .foregroundStyle(Tokens.Ink.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .glassSurface(cornerRadius: 18)

                    Button {
                        dismiss()
                    } label: {
                        Text("Post")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Tokens.Base.dark)
                            .frame(width: 104, height: 52)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Tokens.Accent.signal)
                            }
                    }
                }
            }
            .padding(16)
        }
        .background(Tokens.Base.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION TOTAL")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("16,000")
                    .font(.system(size: 31, weight: .bold))
                    .tabularNumerals()
                    .foregroundStyle(Tokens.Ink.primary)
                Text("m")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            HStack(spacing: 24) {
                StatColumn(label: "TIME", value: "1:04:50")
                StatColumn(label: "AVG /500M", value: "2:01.6")
                StatColumn(label: "RATE", value: "r19")
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
    }

    private func segmentRow(_ segment: MockSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Tokens.Ink.primary.opacity(0.08))
                    .frame(width: 44, height: 44)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 3) {
                    fieldLabel("DISTANCE", segment.dist, lowConfidence: segment.lowConfidence)
                    fieldLabel("TIME", segment.time, lowConfidence: segment.lowConfidence)
                    fieldLabel("/500M", segment.split, lowConfidence: false)
                    fieldLabel("RATE", segment.rate, lowConfidence: false)
                }
            }
            if segment.lowConfidence {
                Text("Two values read with low confidence — worth a check.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Tokens.Accent.signal)
            }
            HStack(spacing: 6) {
                ForEach(["WARMUP", "MAIN", "COOLDOWN", "EXTRA"], id: \.self) { tag in
                    FilterChip(label: tag, isSelected: tag == segment.tag)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.05))
        }
    }

    /// Low-confidence fields get a cyan underline and are pre-focused —
    /// never red, per CLAUDE.md. This is expected, not an error state.
    private func fieldLabel(_ label: String, _ value: String, lowConfidence: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
                .overlay(alignment: .bottom) {
                    if lowConfidence {
                        Rectangle()
                            .fill(Tokens.Accent.signal.opacity(0.8))
                            .frame(height: 2)
                            .offset(y: 2)
                    }
                }
        }
    }

    private var testDetectedBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This looks like a 2k test.")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Tokens.Ink.primary)
                Text("Add it to the 2k leaderboard?")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text("Yes")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Tokens.Base.dark)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tokens.Accent.signal)
                }
            Text("No")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.Ink.primary.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Tokens.Ink.primary.opacity(0.1))
                }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Accent.signal.opacity(0.14))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Tokens.Accent.signal.opacity(0.35), lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        ReviewSheetView()
    }
}
