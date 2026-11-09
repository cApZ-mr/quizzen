//
//  ProfileComponents.swift
//  IOS - Quizzen
//
//  Gemeinsame Bausteine für das eigene und das öffentliche Profil,
//  damit beide identisch aussehen.
//

import SwiftUI

// MARK: - Kopfbereich: Banner, Avatar mit Level-Ring, Name, Herkunft

struct ProfileHeroHeader<Actions: View>: View {
    let username: String
    var avatarImage: Image? = nil
    var avatarUrl: String? = nil
    let bannerId: String?
    let level: PlayerLevel
    let countryCode: String?
    let memberSince: Date?
    @ViewBuilder var actions: () -> Actions

    private var countryName: String? {
        guard let code = countryCode, !code.isEmpty else { return nil }
        return UserViewModel.allCountries.first { $0.code.lowercased() == code.lowercased() }?.name
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                ProfileBannerView(bannerId: bannerId)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .overlay(LinearGradient(colors: [.clear, Color(.systemGroupedBackground)],
                                            startPoint: .center, endPoint: .bottom))

                ZStack(alignment: .bottomTrailing) {
                    AvatarView(username: username, url: avatarUrl, size: 112, image: avatarImage)
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 5))
                        .overlay(
                            Circle()
                                .trim(from: 0, to: level.progress)
                                .stroke(level.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .padding(-4)
                        )

                    Text("\(level.level)")
                        .font(.system(.subheadline, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(level.color, in: Circle())
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 3))
                        .accessibilityLabel("Level \(level.level)")
                }
                .offset(y: 56)
            }
            .padding(.bottom, 56)

            Text(username)
                .font(.system(.title, design: .rounded).weight(.bold))

            Text(level.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(level.color)

            HStack(spacing: 8) {
                if let countryCode, let countryName {
                    FlagImage(name: countryCode.lowercased(), width: 20, height: 14)
                    Text(countryName)
                }
                if countryName != nil, memberSince != nil { Text("·") }
                if let memberSince {
                    Text("Dabei seit \(memberSince.formatted(.dateTime.month(.wide).year()))")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            actions()
                .padding(.top, 4)
        }
    }
}

// MARK: - Level-Karte

struct ProfileLevelCard: View {
    let level: PlayerLevel
    var showsHowToEarn: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(level.level)")
                        .font(.headline)
                    Text(level.title)
                        .font(.subheadline)
                        .foregroundStyle(level.color)
                }
                Spacer()
                Text("\(level.xp.formatted()) XP")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: level.progress)
                .tint(level.color)

            Text(showsHowToEarn
                 ? "Noch \((level.xpForNextLevel - level.xpIntoLevel).formatted()) XP bis Level \(level.level + 1) · \(PlayerLevel.xpPerCorrectAnswer) XP pro richtiger Antwort, \(PlayerLevel.xpPerRound) XP pro Runde"
                 : "Noch \((level.xpForNextLevel - level.xpIntoLevel).formatted()) XP bis Level \(level.level + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

// MARK: - Kennzahlen (2×2)

struct ProfileStatsGrid<FriendsDestination: View>: View {
    let stats: GlobalStats
    let friendsCount: Int
    /// Optionales Ziel beim Tippen auf „Freunde“
    var friendsDestination: FriendsDestination?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ProfileStatCard(value: "\(stats.currentStreak)",
                            label: stats.currentStreak == 1 ? "Tag Streak" : "Tage Streak",
                            icon: "flame.fill", color: .orange,
                            footnote: "Rekord: \(stats.bestStreak)")
            ProfileStatCard(value: "\(stats.accuracy) %", label: "Trefferquote", icon: "target", color: .green,
                            footnote: "\(stats.correctAnswers.formatted()) von \(stats.totalAnswers.formatted())")
            ProfileStatCard(value: stats.quizzesPlayed.formatted(), label: "Runden gespielt",
                            icon: "arrow.triangle.2.circlepath", color: .blue,
                            footnote: "Spielzeit: \(Self.formatPlayTime(stats.playTime))")
            if let friendsDestination {
                NavigationLink { friendsDestination } label: {
                    ProfileStatCard(value: "\(friendsCount)", label: friendsCount == 1 ? "Freund" : "Freunde", icon: "person.2.fill", color: .purple,
                                    footnote: "Anzeigen ›")
                }
                .buttonStyle(.plain)
            } else {
                ProfileStatCard(value: "\(friendsCount)", label: friendsCount == 1 ? "Freund" : "Freunde", icon: "person.2.fill", color: .purple,
                                footnote: friendsCount == 1 ? "1 Freund" : "\(friendsCount) Freunde")
            }
        }
        .padding(.horizontal)
    }

    static func formatPlayTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "0 Min."
    }
}

extension ProfileStatsGrid where FriendsDestination == EmptyView {
    init(stats: GlobalStats, friendsCount: Int) {
        self.stats = stats
        self.friendsCount = friendsCount
        self.friendsDestination = nil
    }
}

struct ProfileStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.subheadline)
            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Abzeichen-Vitrine

struct ProfileBadgeShowcase<SeeAll: View>: View {
    let badges: [Badge]
    var title: String = "Abzeichen"
    @ViewBuilder var seeAll: () -> SeeAll

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                NavigationLink("Alle ansehen") { seeAll() }
                    .font(.subheadline)
            }
            if badges.isEmpty {
                Text("Noch keine Abzeichen freigeschaltet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(badges) { badge in
                        CompactBadgeHexagon(badge: badge)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

extension Badge {
    /// Badges für die Vitrine: die im Social-Profil gewählten (in Reihenfolge),
    /// sonst die mit dem höchsten Level.
    static func showcase(from stats: GlobalStats, selected: [String], limit: Int = 4) -> [Badge] {
        let all = Badge.make(from: stats)
        let chosen = selected.compactMap { id in all.first { $0.identifier == id && !$0.isLocked } }
        if !chosen.isEmpty { return Array(chosen.prefix(limit)) }
        return Array(all.filter { !$0.isLocked }
            .sorted { ($0.isSpecial ? -1 : $0.level) > ($1.isSpecial ? -1 : $1.level) }
            .prefix(limit))
    }
}
