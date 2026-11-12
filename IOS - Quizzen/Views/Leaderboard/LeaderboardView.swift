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
    @EnvironmentObject var router: AppRouter

    @StateObject private var viewModel = LeaderboardViewModel()
    @State private var showQuizPicker = false
    @Namespace private var scopeNamespace

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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
        .onAppear(perform: applyRequestedBoard)
        .onChange(of: router.requestedBoard) { _, _ in applyRequestedBoard() }
    }

    /// Ändert sich Bestenliste oder Filter, wird neu geladen.
    private var reloadKey: String { viewModel.board.id + viewModel.scope.rawValue }

    private func applyRequestedBoard() {
        guard let board = router.requestedBoard else { return }
        router.requestedBoard = nil
        viewModel.board = board
    }

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

    /// Bereich: Weltweit / Freunde / Mein Land
    private var scopePicker: some View {
        HStack(spacing: 4) {
            ForEach(LeaderboardScope.allCases) { scope in
                let isActive = scope == viewModel.scope
                Button {
                    withAnimation(.snappy) { viewModel.scope = scope }
                } label: {
                    Label(scope.title, systemImage: scope.icon)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isActive ? .white : .secondary)
                        .background {
                            if isActive {
                                Capsule()
                                    .fill(Color.brand.gradient)
                                    .matchedGeometryEffect(id: "scope", in: scopeNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .padding(.horizontal)
    }

    /// Bestenlisten als Kacheln: allgemeine Listen + eine Kachel für die Quizze
    private var boardChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(LeaderboardBoard.general) { board in
                            boardTile(icon: board.icon, title: board.title, tint: board.tint,
                                      isActive: board == viewModel.board) {
                                withAnimation(.snappy) { viewModel.board = board }
                            }
                            .id(board.id)
                        }
                        quizTile.id("quizzes")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                }
                .onChange(of: viewModel.board) { _, board in
                    withAnimation { proxy.scrollTo(board.isQuiz ? "quizzes" : board.id, anchor: .center) }
                }
            }

            // Was wird gezählt?
            HStack(spacing: 10) {
                Image(systemName: viewModel.board.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(viewModel.board.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.board.isQuiz ? viewModel.board.title : boardHeadline)
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.board.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .animation(.snappy, value: viewModel.board)
        }
        .sheet(isPresented: $showQuizPicker) {
            QuizBoardPicker(selected: viewModel.board) { board in
                withAnimation(.snappy) { viewModel.board = board }
            }
        }
    }

    private var boardHeadline: String {
        switch viewModel.board {
        case .stat(let metric): metric.title
        case .daily: String(localized: "Tageschallenge")
        case .quiz(_, let name, _): name
        }
    }

    private var quizTile: some View {
        let board = viewModel.board
        return boardTile(icon: board.isQuiz ? board.icon : "square.grid.2x2.fill",
                         title: board.isQuiz ? board.title : String(localized: "Quizze"),
                         tint: board.isQuiz ? board.tint : .indigo,
                         isActive: board.isQuiz,
                         showsChevron: true) {
            showQuizPicker = true
        }
    }

    private func boardTile(icon: String, title: String, tint: Color, isActive: Bool,
                           showsChevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isActive ? tint : .white)
                        .frame(width: 32, height: 32)
                        .background(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(tint.gradient), in: Circle())
                    Spacer(minLength: 0)
                    if showsChevron {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
                    }
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isActive ? .white : .primary)
            }
            .padding(12)
            .frame(width: 112, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isActive ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            )
            .shadow(color: isActive ? tint.opacity(0.35) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
                                ? String(localized: "Lege in deinem Profil ein Land fest.")
                                : String(localized: "In deinem Land hat hier noch niemand gepunktet. Sei die erste Person!"))
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
                Text(isMe ? String(localized: "\(entry.account.username) (Du)") : entry.account.username)
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

// MARK: - Quiz-Auswahl

/// Sheet mit allen Quizzen, gruppiert nach Themenbereich
private struct QuizBoardPicker: View {
    let selected: LeaderboardBoard
    let onSelect: (LeaderboardBoard) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(QuizCatalog.categories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(category.name, systemImage: category.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(category.color)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(category.quizzes) { quiz in
                                    let board = LeaderboardBoard.quiz(id: quiz.id, name: quiz.title, icon: quiz.icon)
                                    tile(board, quiz: quiz, color: category.color)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Quiz-Bestenliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func tile(_ board: LeaderboardBoard, quiz: QuizDefinition, color: Color) -> some View {
        let isActive = board == selected
        return Button {
            onSelect(board)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: quiz.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 10))
                Text(quiz.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(color)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isActive ? color : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
