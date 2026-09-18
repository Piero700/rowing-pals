//
//  InsetCornerPickerView.swift
//  Rowing Pals
//

import SwiftUI

/// Sheet for choosing which corner the front-camera inset preview sits in
/// over the full-bleed rear-camera preview — 4 explicit positions, per the
/// redesign handoff (§2 Screen 04, §3): "a corner-picker sheet with 4
/// explicit buttons." Genuinely configurable, not a fixed corner, and
/// entirely separate from any "swap cameras" control, which flips which
/// physical camera is main vs inset rather than where the inset sits.
///
/// Takes the selection as a `Binding<InsetCorner>` rather than owning
/// `@AppStorage` itself, so the same sheet works regardless of what backs
/// the selection at the call site — the capture screen persists it via
/// `@AppStorage`; a future feed-card or workout-hero use could do the same.
///
/// Built here in `Features/Capture` for this task; nothing about it is
/// capture-specific, so a later phase can lift it into `DesignSystem`
/// alongside `InsetCorner` itself if the feed card or workout-hero detail
/// end up wanting the identical sheet rather than their own variant.
struct InsetCornerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: InsetCorner

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Choose which corner the front camera preview sits in.")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(InsetCorner.allCases) { corner in
                        option(for: corner)
                    }
                }
            }
            .padding(20)
            .background(Tokens.Base.ground)
            .navigationTitle("Inset position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func option(for corner: InsetCorner) -> some View {
        let isSelected = corner == selection
        return Button {
            withAnimation(.snappy) { selection = corner }
            dismiss()
        } label: {
            VStack(spacing: 10) {
                InsetCornerGlyph(corner: corner, tint: isSelected ? Tokens.Accent.brand : Tokens.Ink.secondary)
                    .frame(width: 44, height: 34)
                Text(corner.label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Tokens.Ink.primary : Tokens.Ink.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        // `.interactiveGlassSurface` is exactly Glass.swift's primitive for
        // "an interactive glass surface tinted with one of the accent
        // tokens... for a control the user taps" — the selected option gets
        // the brand tint (this app's one "active/selected control" role),
        // the rest stay neutral.
        .interactiveGlassSurface(cornerRadius: 18, tint: isSelected ? Tokens.Accent.brand : Tokens.Surface.raised)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    InsetCornerPickerView(selection: .constant(.topTrailing))
}
