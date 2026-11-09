//
//  LeaderboardView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 12.07.26.
//

import Foundation
import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var friendsViewModel: FriendsViewModel

    @StateObject private var viewModel = LeaderboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    scopePicker
                    boardChips
                    content
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bestenliste")
            .refreshable { await reload() }
            .safeAreaInset(edge: .bottom) { myRankBar }
            .navigationDestination(for: Account.self) { PublicProfileView(account: $0) }
        }
        .task(id: reloadKey) { await reload() }
    }

    /// Ändert sich Bestenliste oder Filter, wird neu geladen.
    private var reloadKey: String { viewModel.board.id + viewModel.scope.rawValue }

    private func reload() async {
        if viewModel.scope == .friends && friendsViewModel.friends.isEmpty {
            await friendsViewModel.loadFriends()
        }
        await viewModel.load(
            myStats: statsManager.globalManager.stats,
            friendIds: friendsViewModel.friends.map(\.id),
            countryCode: userViewModel.selectedOriginCode
        )
    }

    // MARK: - Filter

    private var scopePicker: some View {
        Picker("Bereich", selection: $viewModel.scope) {
            ForEach(LeaderboardScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var boardChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LeaderboardBoard.all) { board in
                    let isActive = board == viewModel.board
                    Button {
                        withAnimation(.snappy) { viewModel.board = board }
                    } label: {
                        Label(board.title, systemImage: board.icon)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(isActive ? Color.brand : Color(.secondarySystemGroupedBackground), in: Capsule())
                            .foregroundStyle(isActive ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            placeholderList
        case .loading where viewModel.entries.isEmpty:
            placeholderList
        case .failed(let message):
            ContentUnavailableView {
                Label("Nicht verfügbar", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Erneut versuchen") { Task { await reload() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.brand)
            }
            .padding(.top, 40)
        default:
            if viewModel.entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 20) {
                    Text(viewModel.board.unit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    podium
                    list
                }
                .opacity(viewModel.state == .loading ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.2), value: viewModel.state)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch keine Einträge", systemImage: "trophy")
        } description: {
            switch viewModel.scope {
            case .friends: Text("Füge Freunde hinzu, um euch zu vergleichen.")
            case .country: Text(userViewModel.selectedOriginCode.isEmpty
                                ? "Lege in deinem Profil ein Land fest."
                                : "In deinem Land hat hier noch niemand gepunktet. Sei die erste Person!")
            case .global:  Text("Spiel ein Quiz und sichere dir den ersten Platz!")
            }
        }
        .padding(.top, 40)
    }

    private var placeholderList: some View {
        VStack(spacing: 10) {
            ForEach(0..<8, id: \.self) { index in
                row(LeaderboardEntry(
                    account: Account(id: UUID(), username: "Platzhalter", avatarUrl: nil, country: nil, createdAt: .now),
                    value: 100, rank: index + 1))
            }
        }
        .redacted(reason: .placeholder)
        .padding(.horizontal)
    }

    // MARK: Podium (Plätze 1–3)

    private var podium: some View {
        let top = Array(viewModel.entries.prefix(3))
        // Anordnung: 2 – 1 – 3
        let order = [1, 0, 2].filter { $0 < top.count }

        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(order, id: \.self) { index in
                podiumColumn(top[index], height: [120, 90, 70][index])
            }
        }
        .padding(.horizontal)
    }

    private func podiumColumn(_ entry: LeaderboardEntry, height: CGFloat) -> some View {
        let medal = medalColor(entry.rank)
        let isFirst = entry.rank == 1

        return NavigationLink(value: entry.account) {
            VStack(spacing: 8) {
                ZStack(alignment: .top) {
                    AvatarView(username: entry.account.username, url: entry.account.avatarUrl, size: isFirst ? 76 : 60)
                        .overlay(Circle().stroke(medal, lineWidth: 3))
                        .padding(.top, isFirst ? 18 : 0)
                    if isFirst {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(entry.account.username)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(viewModel.isMe(entry) ? Color.brandLight : .primary)

                VStack(spacing: 4) {
                    Text("\(entry.rank)")
                        .font(.system(.title, design: .rounded).weight(.black))
                    Text(viewModel.board.format(entry.value))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(medal.gradient, in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Platz \(entry.rank), \(entry.account.username), \(viewModel.board.format(entry.value))")
    }

    // MARK: Liste ab Platz 4

    private var list: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.entries.dropFirst(3)) { entry in
                NavigationLink(value: entry.account) {
                    row(entry)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        let isMe = viewModel.isMe(entry)
        return HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32)

            AvatarView(username: entry.account.username, url: entry.account.avatarUrl, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "\(entry.account.username) (Du)" : entry.account.username)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let country = entry.account.country, !country.isEmpty {
                    FlagImage(name: country.lowercased(), width: 18, height: 12)
                }
            }

            Spacer()

            Text(viewModel.board.format(entry.value))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isMe ? Color.brand.opacity(0.25) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isMe ? Color.brandLight : .clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Eigener Platz (unten fixiert)

    @ViewBuilder
    private var myRankBar: some View {
        let stats = statsManager.globalManager.stats
        let isVisibleInList = viewModel.entries.contains { viewModel.isMe($0) }

        if viewModel.state == .loaded, !isVisibleInList {
            HStack(spacing: 12) {
                AvatarView(username: userViewModel.username, url: nil, size: 36, image: userViewModel.profileImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dein Platz")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let rank = viewModel.myRank {
                        Text("#\(rank)").font(.headline)
                    } else {
                        Text("Noch nicht platziert").font(.subheadline.weight(.semibold))
                    }
                }
                Spacer()
                if case .stat(let metric) = viewModel.board {
                    Text(metric.formatted(metric.value(in: stats)))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: Color(hex: "E3B23C")
        case 2: Color(hex: "A7B0BA")
        default: Color(hex: "B87333")
        }
    }
}
