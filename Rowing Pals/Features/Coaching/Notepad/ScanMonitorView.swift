//
//  ScanMonitorView.swift
//  Rowing Pals
//

import PhotosUI
import SwiftUI

/// Scan a monitor, to the v4 CoachNotepadScan artboard (decision 96, NP2): photograph a rower's
/// results screen, see the pieces read (new ones highlighted, overlap kept once), scan the next
/// screen until they're all in, then **Fill [name]'s row**. Opened from the camera button by a
/// name on the notepad. Only the numbers are kept: each photo is released once it's read.
struct ScanMonitorView: View {
    @State private var viewModel: ScanMonitorViewModel
    @State private var camera: CaptureViewModel
    @Environment(\.dismiss) private var dismiss
    #if targetEnvironment(simulator)
    /// The simulator has no camera: a photo from its library stands in for one, to test reading.
    @State private var libraryItem: PhotosPickerItem?
    #endif

    init(workoutId: UUID, rowerId: UUID) {
        _viewModel = State(initialValue: ScanMonitorViewModel(workoutId: workoutId, rowerId: rowerId))
        _camera = State(initialValue: CaptureViewModel(rearOnly: true))
    }

    var body: some View {
        VStack(spacing: 0) {
            screensRow
            if viewModel.isCapturing {
                capture
            } else {
                review
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenHeader(title: viewModel.title.isEmpty ? "Scan a monitor" : viewModel.title) { dismiss() }
        }
        .background(Tokens.Base.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: viewModel.isCapturing) { _, capturing in
            if capturing { camera.start() } else { camera.stop() }
        }
    }

    // MARK: - Screens and count

    /// "Screen 1 · Screen 2 · Screen 3" and "8 of 20 read".
    private var screensRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<chipCount, id: \.self) { index in
                let isTaken = index < viewModel.screens
                let isNext = index == viewModel.screens && viewModel.isCapturing
                Text("Screen \(index + 1)")
                    .textStyle(Typography.chip)
                    .tabularNumerals()
                    .foregroundStyle(isTaken ? Tokens.Ink.primary : (isNext ? Tokens.Accent.brand : Tokens.Ink.faint))
                    .padding(.horizontal, 10)
                    .frame(minHeight: Tokens.Size.chip + 4)
                    .background(Capsule().fill(isTaken ? Tokens.Surface.raised : (isNext ? Tokens.Accent.brandSoft : Color.clear)))
            }
            Spacer(minLength: Tokens.Spacing.tight)
            Text(viewModel.countLabel)
                .textStyle(Typography.pill)
                .tabularNumerals()
                .foregroundStyle(viewModel.isDone ? Tokens.Accent.success : Tokens.Ink.secondary)
        }
        .padding(.horizontal, Tokens.Spacing.screen)
        .padding(.bottom, 10)
    }

    private var chipCount: Int { max(1, viewModel.screens + (viewModel.isCapturing ? 1 : 0)) }

    // MARK: - Taking a photo

    private var capture: some View {
        VStack(spacing: Tokens.Spacing.loose) {
            finder
            if case .failed(let message) = camera.phase {
                // The camera's own reason (user, 2026-11-05: "I get an error and it doesn't show a preview").
                VStack(spacing: Tokens.Spacing.tight) {
                    Text(message)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.System.error)
                        .multilineTextAlignment(.center)
                    HStack(spacing: Tokens.Spacing.group) {
                        Button("Try again") { camera.retry() }
                            .buttonStyle(.rpText)
                        if camera.isPermissionDenied, let settings = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open Settings", destination: settings)
                                .textStyle(Typography.detail)
                                .foregroundStyle(Tokens.Accent.brand)
                        }
                    }
                }
            } else {
                Text(viewModel.errorMessage ?? viewModel.finderHelp)
                    .textStyle(Typography.meta)
                    .foregroundStyle(viewModel.errorMessage == nil ? Tokens.Ink.secondary : Tokens.System.error)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 28) {
                if viewModel.screens > 0 {
                    Button("Back to list") { viewModel.isCapturing = false }
                        .buttonStyle(.rpText)
                }
                shutter
                #if targetEnvironment(simulator)
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Text("Choose a photo")
                }
                .buttonStyle(.rpText)
                .onChange(of: libraryItem) { _, item in
                    guard let item else { return }
                    libraryItem = nil
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) { await viewModel.read(data) }
                    }
                }
                #endif
            }
        }
        .padding([.horizontal, .bottom], Tokens.Spacing.screen)
    }

    /// The camera, with the frame to fit the results inside and what to point it at.
    private var finder: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Notepad.finderRadius, style: .continuous)
        return ZStack {
            if let layer = camera.rearPreviewLayer {
                CameraPreviewView(previewLayer: layer)
            } else {
                PhotoPlaceholder(cornerRadius: 0)
            }
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: Tokens.Notepad.finderFrameRadius, style: .continuous)
                    .strokeBorder(Tokens.Ink.primary.opacity(Tokens.Notepad.finderFrameOpacity), lineWidth: Tokens.Notepad.finderFrameLine)
                    .padding(.horizontal, geometry.size.width * Tokens.Notepad.finderFrameInsetX)
                    .padding(.vertical, geometry.size.height * Tokens.Notepad.finderFrameInsetY)
            }
            if viewModel.isReading {
                ProgressView().tint(Tokens.Ink.primary)
            } else if camera.rearPreviewLayer == nil {
                Text(camera.phase == .configuring ? "STARTING CAMERA…" : viewModel.finderLabel)
                    .textStyle(Typography.meta)
                    .monospaced()
                    .foregroundStyle(Tokens.Ink.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.finderLabel.capitalized)
    }

    private var shutter: some View {
        Button {
            Task {
                guard let photo = await camera.captureMonitorPhoto() else { return }
                await viewModel.read(photo)
                camera.phase = .ready
            }
        } label: {
            Circle()
                .strokeBorder(Tokens.Ink.primary, lineWidth: Tokens.Notepad.shutterRing)
                .frame(width: Tokens.Notepad.shutter, height: Tokens.Notepad.shutter)
                .overlay {
                    Circle().fill(Tokens.Ink.primary).frame(width: Tokens.Notepad.shutterDot, height: Tokens.Notepad.shutterDot)
                }
        }
        .buttonStyle(IconPressStyle())
        .disabled(viewModel.isReading || camera.phase != .ready)
        .accessibilityLabel("Take photo")
    }

    // MARK: - What was read

    private var review: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    banner
                    piecesTable
                    Text(viewModel.footnote)
                        .textStyle(Typography.meta)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 4)
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .textStyle(Typography.meta)
                            .foregroundStyle(Tokens.System.error)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, Tokens.Spacing.screen)
                .padding(.bottom, Tokens.Spacing.screen)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: Tokens.Spacing.tight) {
                if !viewModel.isDone {
                    Button {
                        viewModel.isCapturing = true
                    } label: {
                        Label("Scan the next screen", icon: .camera, size: Tokens.Icon.small)
                    }
                    .buttonStyle(.rpGlass)
                }
                Button(viewModel.fillLabel) {
                    Task { if await viewModel.fill() { dismiss() } }
                }
                .buttonStyle(.rpPrimary)
                .disabled(viewModel.isFilling || viewModel.readCount == 0)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.top, Tokens.Spacing.loose)
            .padding(.bottom, Tokens.Spacing.group)
        }
    }

    /// "Read from screen 2. The photo has been deleted, only these numbers are kept."
    private var banner: some View {
        HStack(spacing: Tokens.Spacing.tight) {
            RPIconView(icon: .camera, size: Tokens.Icon.small)
                .foregroundStyle(Tokens.Accent.brand)
            Text(viewModel.banner)
                .textStyle(Typography.meta)
                .foregroundStyle(Tokens.Ink.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.Notepad.bannerRadius, style: .continuous).fill(Tokens.Accent.brandSoft))
    }

    /// # · Time · Split · Metres · Rate, one row per piece, new ones highlighted.
    private var piecesTable: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Notepad.tableRadius, style: .continuous)
        return VStack(spacing: 0) {
            pieceRow(number: "#", time: "Time", split: "Split", metres: "Metres", rate: "Rate", isHeader: true)
            ForEach(Array(viewModel.rows.enumerated()), id: \.offset) { index, row in
                pieceRow(
                    number: "\(index + 1)",
                    time: row.timeMs.map(WorkoutRules.splitTenthsText) ?? "–",
                    split: row.splitMs.map(WorkoutRules.splitTenthsText) ?? "–",
                    metres: row.distanceM.map(\.formattedWithGrouping) ?? "–",
                    rate: row.rate.map { "\($0)" } ?? "–",
                    isHeader: false
                )
                .background(viewModel.newIndices.contains(index) ? Tokens.Accent.brandSoft : Color.clear)
                .overlay(alignment: .top) { Rectangle().fill(Tokens.Surface.cardEdge).frame(height: 1) }
            }
        }
        .background(shape.fill(Tokens.Surface.card))
        .overlay { shape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
        .clipShape(shape)
    }

    private func pieceRow(number: String, time: String, split: String, metres: String, rate: String, isHeader: Bool) -> some View {
        HStack(spacing: 4) {
            Text(number)
                .textStyle(isHeader ? Typography.tag : Typography.meta)
                .foregroundStyle(isHeader ? Tokens.Ink.secondary : Tokens.Ink.faint)
                .frame(width: Tokens.Notepad.scanNumberColumn, alignment: .leading)
            Text(time)
                .textStyle(isHeader ? Typography.tag : Typography.detail)
                .foregroundStyle(isHeader ? Tokens.Ink.secondary : Tokens.Ink.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(split)
                .textStyle(isHeader ? Typography.tag : Typography.rowTitle)
                .foregroundStyle(isHeader ? Tokens.Ink.secondary : Tokens.Ink.primary)
                .frame(width: Tokens.Notepad.scanValueColumn, alignment: .trailing)
            Text(metres)
                .textStyle(isHeader ? Typography.tag : Typography.detail)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: Tokens.Notepad.scanValueColumn, alignment: .trailing)
            Text(rate)
                .textStyle(isHeader ? Typography.tag : Typography.detail)
                .foregroundStyle(Tokens.Ink.secondary)
                .frame(width: Tokens.Notepad.scanRateColumn, alignment: .trailing)
        }
        .tabularNumerals()
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(minHeight: isHeader ? Tokens.Size.chip + 8 : Tokens.Notepad.scanRowHeight)
        .accessibilityElement(children: .combine)
    }
}
