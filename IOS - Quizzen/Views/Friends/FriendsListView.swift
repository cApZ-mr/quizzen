//
//  FriendsListView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.07.26.
//

import Foundation
import SwiftUI

/// Liste der eigenen Freunde (aus dem Profil erreichbar).
struct FriendsListView: View {
    @EnvironmentObject var friendsViewModel: FriendsViewModel
    @State private var searchText = ""

    private var filteredFriends: [FriendWithSince] {
        let sorted = friendsViewModel.friends.sorted {
            $0.account.username.localizedCaseInsensitiveCompare($1.account.username) == .orderedAscending
        }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.account.username.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredFriends) { friend in
                NavigationLink {
                    PublicProfileView(account: friend.account.asAccount)
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(username: friend.account.username, url: friend.account.avatarUrl, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.account.username)
                                .font(.body.weight(.semibold))
                            Text("Freunde seit \(friend.friendsSince.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let streak = friend.account.stats?.currentStreak, streak > 0 {
                            Label("\(streak)", systemImage: "flame.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .overlay {
            if friendsViewModel.isLoadingFriends && friendsViewModel.friends.isEmpty {
                ProgressView()
            } else if filteredFriends.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "Noch keine Freunde" : "Keine Treffer",
                    systemImage: "person.2",
                    description: Text(searchText.isEmpty
                                      ? "Im Tab „Freunde“ kannst du andere suchen und Anfragen senden."
                                      : "Kein Freund heißt „\(searchText)“.")
                )
            }
        }
        .navigationTitle("Freunde")
        .searchable(text: $searchText, prompt: "Freunde durchsuchen")
        .refreshable { await friendsViewModel.loadFriends() }
        .task { if friendsViewModel.friends.isEmpty { await friendsViewModel.loadFriends() } }
    }
}
