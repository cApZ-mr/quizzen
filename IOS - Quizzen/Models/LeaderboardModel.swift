//
//  LeaderboardModel.swift
//  IOS - Quizzen
//

import Foundation

/// Kennzahlen aus user_stats, nach denen global sortiert werden kann.
nonisolated enum LeaderboardMetric: String, CaseIterable, Identifiable, Hashable {
    case correctAnswers = "correct_answers"
    case quizzesPlayed = "quizzes_played"
    case bestStreak = "best_streak"
    case currentStreak = "current_streak"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .correctAnswers: "Richtige Antworten"
        case .quizzesPlayed:  "Gespielte Runden"
        case .bestStreak:     "Beste Streak"
        case .currentStreak:  "Aktuelle Streak"
        }
    }

    var shortTitle: String {
        switch self {
        case .correctAnswers: "Richtige"
        case .quizzesPlayed:  "Runden"
        case .bestStreak:     "Beste Streak"
        case .currentStreak:  "Streak"
        }
    }

    var icon: String {
        switch self {
        case .correctAnswers: "checkmark.circle.fill"
        case .quizzesPlayed:  "arrow.triangle.2.circlepath"
        case .bestStreak:     "flame"
        case .currentStreak:  "flame.fill"
        }
    }

    func value(in stats: GlobalStats) -> Int {
        switch self {
        case .correctAnswers: stats.correctAnswers
        case .quizzesPlayed:  stats.quizzesPlayed
        case .bestStreak:     stats.bestStreak
        case .currentStreak:  stats.currentStreak
        }
    }

    func formatted(_ value: Int) -> String {
        switch self {
        case .bestStreak, .currentStreak: "\(value) \(value == 1 ? "Tag" : "Tage")"
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
        case .daily: "Heute"
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

    var unit: String {
        switch self {
        case .stat(let metric): metric.title
        case .daily: "Punkte in der heutigen Tageschallenge"
        case .quiz: "Gemeisterte Fragen (verschiedene richtig beantwortet)"
        }
    }

    func format(_ value: Int) -> String {
        switch self {
        case .stat(let metric): metric.formatted(value)
        case .daily: "\(value)/\(DailyChallenge.questionCount)"
        case .quiz: "\(value.formatted()) Fragen"
        }
    }

    static var all: [LeaderboardBoard] {
        [.daily] + LeaderboardMetric.allCases.map { .stat($0) }
        + QuizCatalog.all.map { .quiz(id: $0.id, name: $0.title, icon: $0.icon) }
    }
}

nonisolated enum LeaderboardScope: String, CaseIterable, Identifiable {
    case global, friends, country
    var id: String { rawValue }

    var title: String {
        switch self {
        case .global:  "Weltweit"
        case .friends: "Freunde"
        case .country: "Mein Land"
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
