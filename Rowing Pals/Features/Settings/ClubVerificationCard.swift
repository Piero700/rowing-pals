//
//  ClubVerificationCard.swift
//  Rowing Pals
//

import SwiftUI

/// One club on Settings → Club verifications (decision 108): who it is, who asked and what they
/// wrote, then what can be done — Approve or Decline while it waits, Remove the tag once verified,
/// Approve after all once declined.
struct ClubVerificationCard: View {
    let request: ClubVerificationRequest
    let isDeciding: Bool
    let onDecide: (ClubVerificationAdminService.Decision) -> Void

    var body: some View {
        GroupedSection {
            GroupedRow(label: "Club") {
                ClubNameLabel(name: request.clubName, isVerified: request.isVerified)
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Ink.secondary)
                    .lineLimit(1)
            }
            if let location = request.location, !location.isEmpty {
                GroupedDivider()
                GroupedRow(label: "Where") { GroupedValue(text: location, showsChevron: false) }
            }
            GroupedDivider()
            GroupedRow(label: "Members") { GroupedValue(text: "\(request.memberCount)", showsChevron: false) }
            if let name = request.requestedByName {
                GroupedDivider()
                GroupedRow(label: "Asked by") {
                    GroupedValue(text: request.requestedByUsername.map { "\(name) · @\($0)" } ?? name, showsChevron: false)
                }
            }
            GroupedDivider()
            GroupedRow(label: dateLabel) {
                GroupedValue(text: (request.decidedAt ?? request.createdAt).formatted(date: .abbreviated, time: .omitted),
                             showsChevron: false)
            }
            if let message = request.message, !message.isEmpty {
                GroupedDivider()
                Text(message)
                    .textStyle(Typography.detail)
                    .foregroundStyle(Tokens.Ink.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Tokens.Grouped.rowPadding)
                    .padding(.vertical, Tokens.Spacing.loose)
            }
            GroupedDivider()
            if isDeciding {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: Tokens.Grouped.rowHeight)
            } else {
                switch request.status {
                case .pending:
                    GroupedButtonRow(title: "Approve") { onDecide(.approve) }
                    GroupedDivider()
                    GroupedButtonRow(title: "Decline", isDestructive: true) { onDecide(.decline) }
                case .approved:
                    GroupedButtonRow(title: "Remove the verified tag", isDestructive: true) { onDecide(.remove) }
                case .declined, .none:
                    GroupedButtonRow(title: "Approve") { onDecide(.approve) }
                }
            }
        }
    }

    private var dateLabel: String {
        switch request.status {
        case .pending: "Asked"
        case .approved: "Verified"
        case .declined: "Declined"
        case .none: "Tag removed"
        }
    }
}
