//
//  HomeView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 15.05.26.
//

import SwiftUI

// MARK: TabView
struct MainAppContainer: View {
    @StateObject private var router = AppRouter()
    @EnvironmentObject var friendsViewModel: FriendsViewModel

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
            }

            Tab("Duell", systemImage: "bolt.fill", value: AppTab.duel) {
                PvPLobbyView()
            }

            Tab("Bestenliste", systemImage: "trophy", value: AppTab.leaderboard) {
                LeaderboardView()
            }

            Tab("Freunde", systemImage: "person.2", value: AppTab.friends) {
                NavigationStack {
                    FriendsView()
                }
            }
            .badge(friendsViewModel.incomingRequests.count)

            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .environmentObject(router)
        .task { await BlockList.shared.refresh() }
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: Difficulty

    var color: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var body: some View {
        Text(difficulty.title)
            .font(.caption2).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - HomeScreen

struct HomeView: View {
    @EnvironmentObject var viewModel: UserViewModel
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var router: AppRouter

    private let allQuizzes = DataService.loadAllQuizzes()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    DailyChallengeCard()

                    if let spotlight = spotlightQuiz {
                        SpotlightCard(quiz: spotlight.quiz, label: spotlight.label, stats: statsManager.globalManager.stats)
                    }

                    ForEach(QuizCatalog.categories) { category in
                        CategoryRow(category: category, statsManager: statsManager)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: QuizDetail.self) { quiz in QuizDetailView(quiz: quiz) }
            .navigationDestination(for: QuizCategory.self) { category in CategoryView(category: category) }
        }
    }

    /// Angefangenes Quiz zum Weiterspielen, sonst ein täglich wechselndes Quiz.
    private var spotlightQuiz: (quiz: QuizDetail, label: String)? {
        let inProgress = allQuizzes
            .map { ($0, statsManager.getStats(for: $0).percentFinished(totalQuestions: $0.questionCount)) }
            .filter { $0.1 > 0 && $0.1 < 100 }
            .max { $0.1 < $1.1 }
        if let inProgress {
            return (inProgress.0, String(localized: "Weiterspielen · \(inProgress.1) % erkundet"))
        }
        guard !allQuizzes.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return (allQuizzes[day % allQuizzes.count], String(localized: "Empfohlen für dich"))
    }

    // MARK: Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.username.isEmpty ? String(localized: "Hallo 👋") : String(localized: "Hallo, \(viewModel.username) 👋"))
                    .font(.title2).bold()
                Text("Bereit für dein nächstes Quiz?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink {
                ProfileView()
            } label: {
                AvatarView(username: viewModel.username, url: nil, size: 44, image: viewModel.profileImage)
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(statsManager.globalManager.stats.level.level)")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(statsManager.globalManager.stats.level.color, in: Circle())
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profil öffnen")
        }
    }

}

// MARK: - Themenbereich auf der Startseite
struct CategoryRow: View {
    let category: QuizCategory
    @ObservedObject var statsManager: StatsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: category) {
                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(category.color.gradient, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.name).font(.title3.bold()).foregroundStyle(.primary)
                        Text(category.quizzes.count == 1 ? String(localized: "1 Quiz") : String(localized: "\(category.quizzes.count) Quizze"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Alle ansehen")
                        .font(.subheadline)
                        .foregroundStyle(Color.brandLight)
                }
            }
            .buttonStyle(.plain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(category.quizzes) { definition in
                        let quiz = definition.baseQuiz
                        NavigationLink(value: quiz) {
                            CompactQuizCard(quiz: quiz, stats: statsManager.getStats(for: quiz))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

/// Kleine Quiz-Karte für horizontale Reihen
struct CompactQuizCard: View {
    let quiz: QuizDetail
    let stats: CategoryStats

    private var progress: Int { stats.percentFinished(totalQuestions: quiz.questionCount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            QuizCoverView(quiz: quiz)
                .frame(width: 168, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(quiz.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if stats.answeredCount > 0 {
                HStack(spacing: 6) {
                    ProgressView(value: Double(progress), total: 100)
                        .tint(progress == 100 ? .green : .brandLight)
                    Text("\(progress) %")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(String(localized: "\(quiz.questionCount) \(quiz.definition?.unit.plural ?? String(localized: "Fragen")) · \(quiz.definition?.presets.count ?? 1) Stufen"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 168, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Quiz-Karte (Liste)
struct HomeQuizCard: View {
    let quiz: QuizDetail
    let stats: CategoryStats

    private var definition: QuizDefinition? { quiz.definition }
    private var progress: Int { stats.percentFinished(totalQuestions: quiz.questionCount) }

    var body: some View {
        HStack(spacing: 14) {
            QuizCoverView(quiz: quiz)
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 6) {
                Text(quiz.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(String(localized: "\(quiz.questionCount) \(definition?.unit.plural ?? String(localized: "Fragen")) · \(definition?.presets.count ?? 1) Stufen"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Stufen als farbige Punkte (Leicht → Extrem)
                HStack(spacing: 4) {
                    ForEach(definition?.presets.filter { $0.level != .custom } ?? []) { preset in
                        Capsule().fill(preset.color.gradient).frame(width: 14, height: 5)
                    }
                }

                Spacer(minLength: 0)

                if stats.answeredCount > 0 {
                    HStack(spacing: 8) {
                        ProgressView(value: Double(progress), total: 100)
                            .tint(progress == 100 ? .green : .brandLight)
                        Text("\(progress) %")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Noch nicht gespielt")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 124)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tageschallenge
struct DailyChallengeCard: View {
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var router: AppRouter
    /// Wird beim Erscheinen neu gelesen (nach dem Spielen aktualisiert)
    @State private var score: Int?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 0) {
                    Text(Date.now.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.caption2.weight(.bold))
                    Text(Date.now.formatted(.dateTime.day()))
                        .font(.system(.title, design: .rounded, weight: .black))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("TAGESCHALLENGE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.orange)
                if let score {
                    Text("Geschafft: \(score)/\(DailyChallenge.questionCount)")
                        .font(.headline)
                    Text("Morgen gibt's neue Fragen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("10 Fragen aus allen Quizzen")
                        .font(.headline)
                    Text("Für alle gleich · 20 s pro Frage · 1 Versuch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)

            if score != nil {
                Button {
                    router.showLeaderboard(.daily)
                } label: {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                        .background(Color.orange.opacity(0.15), in: Circle())
                }
                .accessibilityLabel("Tages-Bestenliste")
            } else {
                NavigationLink {
                    QuizPlayView(currentQuiz: DailyChallenge.quiz(), statsManager: statsManager)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(.largeTitle))
                        .foregroundStyle(.orange)
                }
                .accessibilityLabel("Tageschallenge starten")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .onAppear { score = DailyChallenge.completedScore() }
    }
}

// MARK: - Spotlight (Streak + Quiz-Empfehlung)
struct SpotlightCard: View {
    let quiz: QuizDetail
    let label: String
    let stats: GlobalStats

    private var playedToday: Bool {
        guard let last = stats.lastPlayedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    private var streakText: String {
        if stats.currentStreak == 0 { return String(localized: "Starte heute eine Streak!") }
        let days = stats.currentStreak == 1 ? String(localized: "1 Tag") : String(localized: "\(stats.currentStreak) Tage")
        if playedToday { return String(localized: "\(days) Streak – heute gesichert ✓") }
        return String(localized: "Spiel heute, um deine Streak von \(days) zu halten")
    }

    var body: some View {
        NavigationLink(value: quiz) {
            HStack(spacing: 14) {
                QuizCoverView(quiz: quiz)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Text(label.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.brandLight)
                    Text(quiz.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Label(streakText, systemImage: playedToday ? "flame.fill" : "flame")
                        .font(.caption)
                        .foregroundStyle(playedToday ? .orange : .secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(.largeTitle))
                    .foregroundStyle(Color.brand)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

// QuizDetail muss Hashable sein für NavigationLink(value:)
extension QuizDetail: Hashable {
    static func == (lhs: QuizDetail, rhs: QuizDetail) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Preview
#Preview {
    MainAppContainer()
}
