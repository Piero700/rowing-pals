//
//  CoachTabHeader.swift
//  Rowing Pals
//

import SwiftUI

/// A coach tab's header, as the rower tabs' (CoachRowers, CoachWorkouts; decision 67): the large
/// title on the left, any round glass buttons, then the coach's own picture, which opens their
/// Profile — where Settings, Edit profile, Switch to rowing and Log out live.
struct CoachTabHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    @State private var me: ViewerContext.Snapshot?
    @Environment(\.navigate) private var navigate

    var body: some View {
        HStack(spacing: Tokens.Spacing.gap) {
            Text(title)
                .textStyle(Typography.largeTitle)
                .foregroundStyle(Tokens.Ink.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing()
            Button {
                navigate(.coachProfile)
            } label: {
                AvatarPlaceholder(diameter: Tokens.Size.iconButton, name: me?.displayName, userId: me?.userId)
                    .overlay { Circle().strokeBorder(Tokens.Glass.edge, lineWidth: 1) }
                    .contentShape(Circle())
            }
            .buttonStyle(IconPressStyle())
            .accessibilityLabel("Your profile and settings")
        }
        .padding(.top, Tokens.Spacing.tight)
        .padding(.horizontal, Tokens.Spacing.headerHorizontal)
        .padding(.bottom, 14)
        .frame(minHeight: Tokens.Size.headerMinHeight)
        .background(Tokens.Base.ground)
        .task { me = try? await ViewerContext.shared.current() }
    }
}

extension CoachTabHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
