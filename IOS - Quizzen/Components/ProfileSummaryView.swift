//
//  ProfileSummaryView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.07.26.
//
//  Öffentliche Profilansicht (fremde Profile + „So sehen dich andere“).
//  Nutzt dieselben Bausteine wie das eigene Profil.
//

import Foundation
import SwiftUI

struct ProfileSummaryView: View {
    let username: String
    let createdAt: Date?
    let avatarUrl: String?
    var avatarImage: Image? = nil
    let bannerId: String?
    let country: String?
    let stats: GlobalStats?
    let friendsCount: Int
    var selectedBadges: [String] = []
    /// Platzhalter-Optik nur während des ersten Ladens
    var isLoading: Bool = false

    var actionContent: AnyView? = nil

    private var resolvedStats: GlobalStats {
        var resolved = stats ?? GlobalStats()
        if let createdAt { resolved.installDate = min(resolved.installDate, createdAt) }
        return resolved
    }

    var body: some View {
        VStack(spacing: 20) {
            ProfileHeroHeader(
                username: username,
                avatarImage: avatarImage,
                avatarUrl: avatarUrl,
                bannerId: bannerId,
                level: resolvedStats.level,
                countryCode: country,
                memberSince: createdAt
            ) {
                if let actionContent { actionContent }
            }

            ProfileLevelCard(level: resolvedStats.level, showsHowToEarn: false)
            ProfileStatsGrid(stats: resolvedStats, friendsCount: friendsCount)
            ProfileBadgeShowcase(badges: Badge.showcase(from: resolvedStats, selected: selectedBadges)) {
                ProfileBadgeDetailView(stats: resolvedStats, username: username)
            }
        }
        .padding(.bottom, 32)
        .redacted(reason: isLoading ? .placeholder : [])
    }
}
