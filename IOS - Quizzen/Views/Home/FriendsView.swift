//
//  FriendsView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.07.26.
//

import Foundation
import SwiftUI

enum FriendsTab: CaseIterable {
    case friends
    case incoming
    case outgoing

    var title: String {
        switch self {
        case .friends: String(localized: "Freunde")
        case .incoming: String(localized: "Anfragen")
        case .outgoing: String(localized: "Gesendet")
        }
    }

    var icon: String {
        switch self {
        case .friends: "person.2.fill"
        case .incoming: "tray.and.arrow.down.fill"
        case .outgoing: "paperplane.fill"
        }
    }
}

struct FriendsView: View {
    @EnvironmentObject var friendsViewModel: FriendsViewModel
    @EnvironmentObject var router: AppRouter
    @State private var selectedTab: FriendsTab = .friends
    @State private var searchText = ""
    @State private var errorMessage: String?
    @Namespace private var tabNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                tabSwitcher

                switch selectedTab {
                case .friends: friendsContent
                case .incoming: incomingContent
                case .outgoing: outgoingContent
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .animation(.snappy, value: selectedTab)
            .animation(.snappy, value: friendsViewModel.incomingRequests.map(\.id))
            .animation(.snappy, value: friendsViewModel.outgoingRequests.map(\.id))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Freunde")
        .navigationDestination(for: FriendWithSince.self) { friend in
            PublicProfileView(account: friend.account.asAccount)
        }
        .navigationDestination(for: Account.self) { account in
            PublicProfileView(account: account)
        }
        .task { await friendsViewModel.loadAll() }
        .refreshable { await friendsViewModel.loadAll() }
        .onAppear {
            // Offene Anfragen zuerst zeigen
            if friendsViewModel.friends.isEmpty, !friendsViewModel.incomingRequests.isEmpty {
                selectedTab = .incoming
            }
        }
        .alert("Das hat nicht geklappt", isPresented: $errorMessage.isPresent()) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Umschalter

    private var tabSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(FriendsTab.allCases, id: \.self) { tab in
                let isActive = tab == selectedTab
                Button {
                    withAnimation(.snappy) { selectedTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                        Text(tab.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let count = badgeCount(for: tab), count > 0 {
                            Text("\(count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isActive ? Color.brand : .white)
                                .padding(.horizontal, 6)
                                .frame(minHeight: 18)
                                .background(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(Color.red), in: Capsule())
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(isActive ? .white : .secondary)
                    .background {
                        if isActive {
                            Capsule()
                                .fill(Color.brand.gradient)
                                .matchedGeometryEffect(id: "tab", in: tabNamespace)
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
    }

    private func badgeCount(for tab: FriendsTab) -> Int? {
        switch tab {
        case .friends: nil
        case .incoming: friendsViewModel.incomingRequests.count
        case .outgoing: friendsViewModel.outgoingRequests.count
        }
    }

    // MARK: - Freunde

    private var filteredFriends: [FriendWithSince] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return friendsViewModel.friends }
        return friendsViewModel.friends.filter { $0.account.username.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private var friendsContent: some View {
        if friendsViewModel.isLoadingFriends && friendsViewModel.friends.isEmpty {
            VStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in placeholderCard }
            }
            .redacted(reason: .placeholder)
        } else if friendsViewModel.friends.isEmpty {
            emptyState(icon: "person.2.fill", tint: .purple,
                       title: String(localized: "Noch keine Freunde"),
                       text: String(localized: "Finde andere über die Suche und fordert euch gegenseitig zum Duell heraus."),
                       action: (String(localized: "Personen suchen"), "magnifyingglass", { router.selectedTab = .search }))
        } else {
            VStack(spacing: 10) {
                if friendsViewModel.friends.count > 5 {
                    searchField
                }

                if !friendsViewModel.incomingRequests.isEmpty {
                    requestsHint
                }

                if filteredFriends.isEmpty {
                    Text("Kein Freund heißt „\(searchText)“.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                } else {
                    ForEach(filteredFriends) { friend in
                        friendCard(friend)
                    }
                }

                Button {
                    router.selectedTab = .search
                } label: {
                    Label("Weitere Freunde finden", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.brandLight)
                        .background(Color.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Freunde durchsuchen", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Hinweis auf offene Anfragen oberhalb der Freundesliste
    private var requestsHint: some View {
        let count = friendsViewModel.incomingRequests.count
        return Button {
            withAnimation(.snappy) { selectedTab = .incoming }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.gradient, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 1 ? String(localized: "1 neue Freundschaftsanfrage")
                                    : String(localized: "\(count) neue Freundschaftsanfragen"))
                        .font(.subheadline.weight(.semibold))
                    Text("Tippe, um sie anzusehen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func friendCard(_ friend: FriendWithSince) -> some View {
        let account = friend.account
        let stats = account.stats
        let level = PlayerLevel(correctAnswers: stats?.correctAnswers ?? 0, quizzesPlayed: stats?.quizzesPlayed ?? 0)
        let streak = stats?.currentStreak ?? 0

        return HStack(spacing: 12) {
            NavigationLink(value: friend) {
                HStack(spacing: 12) {
                    AvatarView(username: account.username, url: account.avatarUrl, size: 52)
                        .overlay(alignment: .bottomTrailing) {
                            Text("\(level.level)")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(level.color.gradient, in: Circle())
                                .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2))
                                .offset(x: 4, y: 4)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(account.username)
                                .font(.headline)
                                .lineLimit(1)
                            if let country = account.country, !country.isEmpty {
                                FlagImage(name: country.lowercased(), width: 18, height: 12)
                            }
                        }
                        HStack(spacing: 10) {
                            Label(level.title, systemImage: "star.fill")
                                .foregroundStyle(level.color)
                            if streak > 0 {
                                Label("\(streak)", systemImage: "flame.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .labelStyle(CompactLabelStyle())

                        Text("Freunde seit \(friend.friendsSince.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                router.challenge(account.asAccount)
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.brand.gradient, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(account.username) zum Duell fordern")
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var placeholderCard: some View {
        HStack(spacing: 12) {
            Circle().frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 6) {
                Text("Platzhalter Name").font(.headline)
                Text("Level und Streak").font(.caption)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Eingehende Anfragen

    @ViewBuilder
    private var incomingContent: some View {
        if friendsViewModel.incomingRequests.isEmpty {
            emptyState(icon: "tray.fill", tint: .orange,
                       title: String(localized: "Keine offenen Anfragen"),
                       text: String(localized: "Wenn dir jemand eine Freundschaftsanfrage schickt, erscheint sie hier."),
                       action: nil)
        } else {
            VStack(spacing: 10) {
                ForEach(friendsViewModel.incomingRequests) { account in
                    requestCard(account) {
                        HStack(spacing: 8) {
                            actionButton(String(localized: "Ablehnen"), icon: "xmark", style: .secondary, account: account) {
                                await friendsViewModel.remove(account)
                            }
                            actionButton(String(localized: "Annehmen"), icon: "checkmark", style: .primary, account: account) {
                                await friendsViewModel.accept(account)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Gesendete Anfragen

    @ViewBuilder
    private var outgoingContent: some View {
        if friendsViewModel.outgoingRequests.isEmpty {
            emptyState(icon: "paperplane.fill", tint: .blue,
                       title: String(localized: "Keine gesendeten Anfragen"),
                       text: String(localized: "Anfragen, die du verschickst, warten hier, bis sie angenommen werden."),
                       action: (String(localized: "Personen suchen"), "magnifyingglass", { router.selectedTab = .search }))
        } else {
            VStack(spacing: 10) {
                ForEach(friendsViewModel.outgoingRequests) { account in
                    requestCard(account, subtitle: String(localized: "Wartet auf Antwort")) {
                        actionButton(String(localized: "Zurückziehen"), icon: "arrow.uturn.backward", style: .secondary, account: account) {
                            await friendsViewModel.remove(account)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bausteine

    private func requestCard<Actions: View>(_ account: Account, subtitle: String? = nil,
                                            @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: account) {
                HStack(spacing: 12) {
                    AvatarView(username: account.username, url: account.avatarUrl, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(account.username).font(.headline).lineLimit(1)
                            if let country = account.country, !country.isEmpty {
                                FlagImage(name: country.lowercased(), width: 18, height: 12)
                            }
                        }
                        Text(subtitle ?? String(localized: "Möchte mit dir befreundet sein"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            actions()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
    }

    private enum ActionStyle { case primary, secondary }

    private func actionButton(_ title: String, icon: String, style: ActionStyle, account: Account,
                              action: @escaping () async -> Bool) -> some View {
        let busy = friendsViewModel.busyIds.contains(account.id)
        return Button {
            Task {
                if !(await action()) {
                    errorMessage = String(localized: "Das hat nicht geklappt. Bitte versuch es erneut.")
                }
            }
        } label: {
            ZStack {
                Label(title, systemImage: icon).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(style == .primary ? .white : .primary) }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(style == .primary ? .white : .primary)
            .background(style == .primary ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Color(.tertiarySystemGroupedBackground)),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func emptyState(icon: String, tint: Color, title: String, text: String,
                            action: (title: String, icon: String, run: () -> Void)?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(tint.gradient, in: Circle())
                .shadow(color: tint.opacity(0.4), radius: 12, y: 6)
            Text(title)
                .font(.title3.bold())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action: action.run) {
                    Label(action.title, systemImage: action.icon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .foregroundStyle(.white)
                        .background(Color.brand.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

/// Icon und Text eng beieinander (für Level/Streak-Zeile)
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
