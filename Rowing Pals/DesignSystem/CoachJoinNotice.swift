//
//  CoachJoinNotice.swift
//  Rowing Pals
//

import SwiftUI

/// "<Club> has coaches" (CoachJoinNotice, decision 34): shown before someone joins, asks to
/// join, or accepts an invitation to a club with coaches, because those coaches will see all
/// their training — even on a private account — plus their age and bodyweight.
struct CoachJoinNotice: View {
    struct Coach: Identifiable {
        let id: UUID
        let name: String
        /// "Co-owner · Coach · Novice".
        let detail: String
    }

    let clubName: String
    let coaches: [Coach]
    /// "Join UEA Boat Club", "Request to join", "Accept invitation".
    let actionTitle: String
    let onContinue: () -> Void
    let onCancel: () -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Image(systemName: "eye")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Tokens.Accent.brand)
                        .frame(width: Tokens.Size.noticeIcon, height: Tokens.Size.noticeIcon)
                        .background(Circle().fill(Tokens.Accent.brandSoft))
                        .accessibilityHidden(true)
                    Text("\(clubName) has coaches")
                        .textStyle(Typography.profileName)
                        .foregroundStyle(Tokens.Ink.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Tokens.Spacing.screen)
                        .accessibilityAddTraits(.isHeader)
                    Text("Its coaches can see all your training in this club, even if your account is private: sessions, photos, tests, PBs, effort ratings and predictions, plus your age and bodyweight.")
                        .textStyle(Typography.detail)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Tokens.Spacing.tight)
                }
                .padding(.horizontal, Tokens.Spacing.tight)
                .padding(.top, Tokens.Spacing.screen)

                VStack(spacing: 0) {
                    ForEach(Array(coaches.enumerated()), id: \.element.id) { index, coach in
                        HStack(spacing: Tokens.Spacing.loose) {
                            AvatarPlaceholder(diameter: Tokens.Size.rowerCardAvatar, name: coach.name, userId: coach.id)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(coach.name)
                                    .textStyle(Typography.rowTitle)
                                    .foregroundStyle(Tokens.Ink.primary)
                                Text(coach.detail)
                                    .textStyle(Typography.meta)
                                    .foregroundStyle(Tokens.Ink.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Tokens.Spacing.card)
                        .padding(.vertical, Tokens.Spacing.loose)
                        .frame(minHeight: Tokens.Size.rowCompact)
                        .accessibilityElement(children: .combine)
                        if index < coaches.count - 1 {
                            Rectangle().fill(Tokens.Surface.line).frame(height: 1)
                        }
                    }
                }
                .background(Self.cardShape.fill(Tokens.Surface.card))
                .clipShape(Self.cardShape)
                .overlay { Self.cardShape.strokeBorder(Tokens.Surface.cardEdge, lineWidth: 1) }
                .padding(.top, Tokens.Spacing.group)

                Text("Everyone else still sees only what your privacy settings allow. You can read this again in Settings → Profile visibility.")
                    .textStyle(Typography.meta)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, Tokens.Spacing.loose)

                Button(actionTitle, action: onContinue)
                    .buttonStyle(.rpPrimary)
                    .padding(.top, Tokens.Spacing.group)
                Button("Not now", action: onCancel)
                    .buttonStyle(.rpText)
                    .padding(.top, Tokens.Spacing.tight)
            }
            .padding(.horizontal, Tokens.Spacing.screen)
            .padding(.bottom, Tokens.Spacing.group)
        }
        .scrollIndicators(.hidden)
        .background(Tokens.Surface.card)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationBackground(Tokens.Surface.card)
    }
}
