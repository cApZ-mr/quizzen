//
//  EditProfilView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 19.06.26.
//

import Foundation
import SwiftUI

struct EditProfilView: View {
    @EnvironmentObject var viewModel: UserViewModel
    @EnvironmentObject var statsManager: StatsManager
    @StateObject private var friendsViewModel = FriendsViewModel()
    @StateObject private var socialViewModel = SocialProfileEditViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            ProfileSummaryView(
                username: viewModel.username,
                createdAt: statsManager.globalManager.stats.installDate,
                avatarUrl: nil,
                avatarImage: viewModel.profileImage,
                bannerId: socialViewModel.selectedBannerId,
                country: viewModel.selectedOriginCode,
                stats: statsManager.globalManager.stats,
                friendsCount: friendsViewModel.friends.count,
                selectedBadges: socialViewModel.selectedBadgeIdentifiers,
                actionContent: AnyView(
                    Label("Vorschau deines öffentlichen Profils", systemImage: "eye")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                )
            )
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await socialViewModel.load()
            await friendsViewModel.loadFriends()
        }
    }
}
