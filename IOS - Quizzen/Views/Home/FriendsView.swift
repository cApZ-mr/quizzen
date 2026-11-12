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
        case .incoming: String(localized: "Eingehend")
        case .outgoing: String(localized: "Ausgehend")
        }
    }

    var icon: String {
        switch self {
        case .friends: "person.2.fill"
        case .incoming: "tray.and.arrow.down.fill"
        case .outgoing: "tray.and.arrow.up.fill"
        }
    }
}

struct FriendsView: View {
    @EnvironmentObject var friendsViewModel: FriendsViewModel
    @State private var selectedTab: FriendsTab = .friends
    @Namespace private var underlineNamespace

    var body: some View {
        content
            .navigationTitle("Freunde")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
            VStack(spacing: 0) {
                tabSwitcher

                Divider()

                Group {
                    switch selectedTab {
                    case .friends: friendsListContent
                    case .incoming: incomingRequestsContent
                    case .outgoing: outgoingRequestsContent
                    }
                }
                .padding(.top, 10)
            }
            .navigationDestination(for: FriendWithSince.self) { friend in
                PublicProfileView(account: friend.account.asAccount)
            }
            .navigationDestination(for: Account.self) { account in
                PublicProfileView(account: account)
            }
        .task {
            await friendsViewModel.loadFriends()
            await friendsViewModel.loadIncomingRequests()
            await friendsViewModel.loadOutgoingRequests()
        }
        .refreshable {
            await friendsViewModel.loadFriends()
            await friendsViewModel.loadIncomingRequests()
            await friendsViewModel.loadOutgoingRequests()
        }
    }

    // MARK: - Tab-Bar-Stil-Switcher mit wandernder Unterstreichung

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(FriendsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(.subheadline))
                            Text(tab.title)
                                .font(.subheadline)

                            if let count = badgeCount(for: tab), count > 0 {
                                Text("\(count)")
                                    .font(.system(.caption2, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                        
                        ZStack {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor)
                                    .frame(height: 2.5)
                                    .matchedGeometryEffect(id: "underline", in: underlineNamespace)
                            } else {
                                Color.clear.frame(height: 2.5)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 25)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
    }

    private func badgeCount(for tab: FriendsTab) -> Int? {
        switch tab {
        case .friends: nil
        case .incoming: friendsViewModel.incomingRequests.count
        case .outgoing: friendsViewModel.outgoingRequests.count
        }
    }

    // MARK: - Inhalt: Freunde
    private var friendsListContent: some View {
        List {
            if friendsViewModel.isLoadingFriends {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if friendsViewModel.friends.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(.largeTitle))
                        .foregroundStyle(.secondary)
                    Text("Noch keine Freunde")
                        .fontWeight(.medium)
                    Text("Nutze die Suche, um andere zu finden")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(friendsViewModel.friends) { friend in
                    NavigationLink(value: friend) {
                        FriendsProfilePreview(friend: friend)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Inhalt: Eingehende Anfragen
    private var incomingRequestsContent: some View {
        List {
            if friendsViewModel.incomingRequests.isEmpty {
                Text("Keine eingehenden Anfragen")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friendsViewModel.incomingRequests) { account in
                    NavigationLink(value: account) {
                        accountRow(account)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Inhalt: Ausgehende Anfragen
    private var outgoingRequestsContent: some View {
        List {
            if friendsViewModel.outgoingRequests.isEmpty {
                Text("Keine ausgehenden Anfragen")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friendsViewModel.outgoingRequests) { account in
                    NavigationLink(value: account) {
                        accountRow(account)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: account.avatarUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            Text(account.username).fontWeight(.medium)
        }
    }
}
