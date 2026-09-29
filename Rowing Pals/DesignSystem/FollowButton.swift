//
//  FollowButton.swift
//  Rowing Pals
//

import SwiftUI

/// The one follow control, used on the post detail, other-rower profile and
/// people lists — docs/design/rowing-pals-redesign-handoff-v2.md §2 Screen 08:
/// "a Follow/Following/Requested/'Follow back' button whose label/style
/// reacts to relationship state". Holds no logic; the caller owns the
/// request and passes the state in, so it stays a plain DesignSystem view.
struct FollowButton: View {
    /// Where the button sits, which sets its size and style.
    enum Variant {
        /// Post detail header: a small capsule, brand-filled for Follow.
        case pill
        /// The same, smaller.
        case compactPill
        /// v3 §08 profile: full width, primary for Follow, glass otherwise.
        case fullWidth
        /// v3 §09 people rows: a 44 pt glass pill in every state.
        case row
    }

    let state: FollowState
    /// True when the other rower already follows the viewer, which turns
    /// "Follow" into "Follow back".
    var followsYou = false
    var isBusy = false
    var variant: Variant = .pill
    let action: () -> Void

    private var label: String {
        switch state {
        case .following: "Following"
        case .requested: "Requested"
        case .notFollowing: followsYou ? "Follow back" : "Follow"
        }
    }

    /// Brand-filled only for the one action that starts a relationship;
    /// Following and Requested are quiet, neutral states.
    private var isProminent: Bool { state == .notFollowing }

    var body: some View {
        Group {
            switch variant {
            case .pill: capsule(compact: false)
            case .compactPill: capsule(compact: true)
            case .fullWidth:
                if isProminent {
                    Button(label, action: action).buttonStyle(.rpPrimary)
                } else {
                    Button(label, action: action).buttonStyle(.rpGlass)
                }
            case .row:
                Button(label, action: action)
                    .buttonStyle(.rpPill(isOn: false))
                    .fixedSize()
            }
        }
        .opacity(isBusy ? 0.6 : 1)
        .disabled(isBusy)
        .accessibilityLabel(label)
    }

    private func capsule(compact: Bool) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: compact ? 11.5 : 13.5, weight: .bold))
                .foregroundStyle(isProminent ? Tokens.Base.dark : Tokens.Ink.primary)
                .padding(.horizontal, compact ? 12 : 16)
                .padding(.vertical, compact ? 8 : 9)
                .background {
                    if isProminent {
                        Capsule().fill(Tokens.Accent.brand)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(Tokens.Ink.primary.opacity(0.16))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        FollowButton(state: .notFollowing) {}
        FollowButton(state: .notFollowing, followsYou: true) {}
        FollowButton(state: .requested, variant: .compactPill) {}
        FollowButton(state: .following, variant: .row) {}
        FollowButton(state: .notFollowing, variant: .fullWidth) {}
    }
    .padding()
    .background(Tokens.Base.ground)
}
