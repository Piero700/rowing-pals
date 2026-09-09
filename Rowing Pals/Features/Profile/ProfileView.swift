//
//  ProfileView.swift
//  Rowing Pals
//

import SwiftUI

/// Screen 7 — profile. Streak, charts and the PB progression view arrive
/// with task 15; this pass is the header, stats row, PB tile grid and photo
/// grid with mock values.
struct ProfileView: View {
    private struct PBTile {
        let label: String
        let time: String
        let split: String
        let date: String
    }

    private let pbTiles = [
        PBTile(label: "500M", time: "1:28.4", split: "1:28.4 /500m", date: "14 Feb"),
        PBTile(label: "1K", time: "3:02.6", split: "1:31.3 /500m", date: "2 Feb"),
        PBTile(label: "2K", time: "6:18.9", split: "1:34.7 /500m", date: "28 Jan"),
        PBTile(label: "5K", time: "17:12.4", split: "1:43.2 /500m", date: "11 Jan"),
        PBTile(label: "6K", time: "20:54.8", split: "1:44.6 /500m", date: "4 Dec"),
        PBTile(label: "10K", time: "35:48.0", split: "1:47.4 /500m", date: "19 Nov"),
        PBTile(label: "30MIN", time: "8,410m", split: "1:47.0 /500m", date: "7 Dec"),
        PBTile(label: "60MIN", time: "16,220m", split: "1:51.0 /500m", date: "22 Oct")
    ]

    private let photoGrid = ["16,000m", "2,000m", "10,000m", "6,000m", "5,000m", "12,000m"]

    var body: some View {
        // Direct ScrollView child, same constraint as FeedView — see its comment.
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statsRow

                sectionLabel("PERSONAL BESTS")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                    ForEach(pbTiles, id: \.label) { tile in
                        pbTile(tile)
                    }
                    emptyPBTile
                }

                sectionLabel("POSTS")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                    ForEach(photoGrid, id: \.self) { distance in
                        photoTile(distance)
                    }
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 14)
        }
        .background(Tokens.Base.ground)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AvatarPlaceholder(diameter: 52)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Piero Ciobanu")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Tokens.Ink.primary)
                    Text("SENIOR · M")
                        .textStyle(Typography.label)
                        .textCase(nil)
                        .foregroundStyle(Tokens.Ink.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Tokens.Ink.primary.opacity(0.12))
                        }
                }
                Text("UEA Boat Club")
                    .textStyle(Typography.bodySecondary)
                    .foregroundStyle(Tokens.Ink.secondary)
            }
            Spacer()
            Text("Edit")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Tokens.Ink.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Tokens.Ink.primary.opacity(0.09))
                }
        }
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack {
            StatColumn(label: "METRES", value: "1.42M", alignment: .center)
                .frame(maxWidth: .infinity)
            StatColumn(label: "WEEK STREAK", value: "14", alignment: .center)
                .frame(maxWidth: .infinity)
            StatColumn(label: "SESSIONS", value: "96", alignment: .center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.07))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(Typography.label)
            .foregroundStyle(Tokens.Ink.secondary)
    }

    private func pbTile(_ tile: PBTile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tile.label)
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary)
            Text(tile.time)
                .font(.system(size: 19, weight: .bold))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.primary)
            Text(tile.split)
                .font(.system(size: 11.5))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary)
            Spacer(minLength: 0)
            Text(tile.date)
                .font(.system(size: 10.5))
                .tabularNumerals()
                .foregroundStyle(Tokens.Ink.secondary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(minHeight: 96, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Ink.primary.opacity(0.07))
        }
    }

    private var emptyPBTile: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("4MIN")
                .textStyle(Typography.label)
                .foregroundStyle(Tokens.Ink.secondary.opacity(0.7))
            Text("—")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Tokens.Ink.secondary.opacity(0.5))
            Spacer(minLength: 0)
            Text("Have a crack")
                .font(.system(size: 10.5))
                .foregroundStyle(Tokens.Ink.secondary.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(minHeight: 96, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Tokens.Ink.primary.opacity(0.14), lineWidth: 1.5)
        }
    }

    private func photoTile(_ distance: String) -> some View {
        PhotoPlaceholder(cornerRadius: 12)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                Text(distance)
                    .font(.system(size: 10, weight: .semibold))
                    .tabularNumerals()
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
                    .padding(6)
            }
    }
}

#Preview {
    ProfileView()
}
