//
//  LeaderboardModel.swift
//  IOS - Quizzen
//

import SwiftUI

/// Kennzahlen aus user_stats, nach denen global sortiert werden kann.
nonisolated enum LeaderboardMetric: String, CaseIterable, Identifiable, Hashable {
    case xp = "xp"
    case quizzesPlayed = "quizzes_played"
    case bestStreak = "best_streak"
    case currentStreak = "current_streak"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .xp:             String(localized: "Erfahrungspunkte (XP)")
        case .quizzesPlayed:  String(localized: "Gespielte Runden")
        case .bestStreak:     String(localized: "Beste Streak")
        case .currentStreak:  String(localized: "Aktuelle Streak")
        }
    }

    var shortTitle: String {
        switch self {
        case .xp:             "XP"
        case .quizzesPlayed:  String(localized: "Runden")
        case .bestStreak:     String(localized: "Beste Streak")
        case .currentStreak:  String(localized: "Streak")
        }
    }

    var icon: String {
        switch self {
        case .xp:             "bolt.fill"
        case .quizzesPlayed:  "arrow.triangle.2.circlepath"
        case .bestStreak:     "flame"
        case .currentStreak:  "flame.fill"
        }
    }

    var tint: Color {
        switch self {
        case .xp:            Color(hex: "D99A00")
        case .quizzesPlayed: .blue
        case .bestStreak:    .red
        case .currentStreak: .orange
        }
    }

    func value(in stats: GlobalStats) -> Int {
        switch self {
        case .xp:             PlayerLevel(correctAnswers: stats.correctAnswers, quizzesPlayed: stats.quizzesPlayed).xp
        case .quizzesPlayed:  stats.quizzesPlayed
        case .bestStreak:     stats.bestStreak
        case .currentStreak:  stats.currentStreak
        }
    }

    func formatted(_ value: Int) -> String {
        switch self {
        case .bestStreak, .currentStreak: "\(value) \(value == 1 ? String(localized: "Tag") : String(localized: "Tage"))"
        case .xp: String(localized: "\(value.formatted()) XP")
        default: value.formatted()
        }
    }
}

/// Eine auswählbare Bestenliste: entweder eine globale Kennzahl
/// oder ein Quiz (Summe der Bestwerte, inkl. früherer Einzel-Quizze).
enum LeaderboardBoard: Hashable, Identifiable {
    case stat(LeaderboardMetric)
    case daily
    case quiz(id: String, name: String, icon: String)

    var id: String {
        switch self {
        case .stat(let metric): "stat_\(metric.rawValue)"
        case .daily: "daily"
        case .quiz(let id, _, _): "quiz_\(id)"
        }
    }

    var title: String {
        switch self {
        case .stat(let metric): metric.shortTitle
        case .daily: String(localized: "Heute")
        case .quiz(_, let name, _): name
        }
    }

    var icon: String {
        switch self {
        case .stat(let metric): metric.icon
        case .daily: "calendar"
        case .quiz(_, _, let icon): icon
        }
    }

    var tint: Color {
        switch self {
        case .stat(let metric): metric.tint
        case .daily: .pink
        case .quiz(let id, _, _): QuizCatalog.category(for: id)?.color ?? .brand
        }
    }

    var isQuiz: Bool {
        if case .quiz = self { return true }
        return false
    }

    /// Allgemeine Bestenlisten (ohne einzelne Quizze)
    static var general: [LeaderboardBoard] {
        [.stat(.xp), .daily, .stat(.currentStreak), .stat(.bestStreak)]
    }

    static var quizzes: [LeaderboardBoard] {
        QuizCatalog.all.map { .quiz(id: $0.id, name: $0.title, icon: $0.icon) }
    }

    var unit: String {
        switch self {
        case .stat(.xp): String(localized: "\(PlayerLevel.xpPerCorrectAnswer) XP pro richtiger Antwort, \(PlayerLevel.xpPerRound) XP pro Runde")
        case .stat(let metric): metric.title
        case .daily: String(localized: "Punkte in der heutigen Tageschallenge")
        case .quiz: String(localized: "Gemeisterte Fragen (verschiedene richtig beantwortet)")
        }
    }

    func format(_ value: Int) -> String {
        switch self {
        case .stat(let metric): metric.formatted(value)
        case .daily: "\(value)/\(DailyChallenge.questionCount)"
        case .quiz: String(localized: "\(value.formatted()) Fragen")
        }
    }

    static var all: [LeaderboardBoard] { general + quizzes }
}

nonisolated enum LeaderboardScope: String, CaseIterable, Identifiable {
    case global, friends, country
    var id: String { rawValue }

    var title: String {
        switch self {
        case .global:  String(localized: "Weltweit")
        case .friends: String(localized: "Freunde")
        case .country: String(localized: "Mein Land")
        }
    }

    var icon: String {
        switch self {
        case .global:  "globe"
        case .friends: "person.2.fill"
        case .country: "flag.fill"
        }
    }
}

nonisolated struct LeaderboardEntry: Identifiable, Hashable {
    let account: Account
    let value: Int
    var rank: Int

    var id: UUID { account.id }
}

extension LeaderboardEntry {
    /// Vergibt Plätze; gleiche Werte teilen sich einen Platz (1, 2, 2, 4 …).
    nonisolated static func ranked(_ items: [(Account, Int)]) -> [LeaderboardEntry] {
        var result: [LeaderboardEntry] = []
        for (index, item) in items.enumerated() {
            let rank: Int
            if let previous = result.last, previous.value == item.1 {
                rank = previous.rank
            } else {
                rank = index + 1
            }
            result.append(LeaderboardEntry(account: item.0, value: item.1, rank: rank))
        }
        return result
    }
}
