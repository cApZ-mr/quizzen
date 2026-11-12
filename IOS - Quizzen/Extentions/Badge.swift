//
//  Badge.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.06.26.
//

import Foundation
import SwiftUI

extension Badge {
    // Kernfunktion: nimmt rohe Werte, unabhängig von der Quelle
    static func make(streak: Int, runden: Int, fragen: Int, richtige: Int, falsche: Int, memberSince: Date) -> [Badge] {
        let progresses: [(BadgeType, Int)] = [
            (.streak, streak),
            (.runden, runden),
            (.fragen, fragen),
            (.richtige, richtige),
            (.falsche, falsche),
        ]

        let memberBadge = Badge(
            identifier: "member",
            color: .teal, icon: "calendar.badge.checkmark", name: String(localized: "Mitglied"),
            goal: memberSince.formatted(date: .numeric, time: .omitted),
            explanation: String(localized: "Dabei seit dem \(memberSince.formatted(date: .long, time: .omitted)). Danke für deinen Support ❤️"),
            isLocked: false,
            level: 1, maxLevel: 1,
            isSpecial: true
        )

        let statBadges = progresses.map { type, value -> Badge in
            let thresholds = type.thresholds
            let level = thresholds.filter { value >= $0 }.count
            let next = level < thresholds.count ? thresholds[level] : nil
            let previous = level > 0 ? thresholds[level - 1] : 0
            let explanation: String
            if let next {
                explanation = String(localized: "Noch \(next - value) \(type.unit) bis Level \(level + 1).")
            } else {
                explanation = String(localized: "Maximales Level erreicht – stark! 🏆")
            }
            return Badge(
                identifier: type.rawValue,
                color: type.color,
                icon: type.icon,
                name: type.name,
                goal: level == 0 ? String(localized: "Noch nicht erreicht") : String(localized: "Level \(level) von \(thresholds.count)"),
                explanation: explanation,
                isLocked: level == 0,
                level: level,
                maxLevel: thresholds.count,
                currentValue: value,
                previousThreshold: previous,
                nextThreshold: next,
                unit: type.unit
            )
        }

        return [memberBadge] + statBadges
    }

    // Bequemlichkeits-Overload für die eigenen, lokalen Stats (wie bisher)
    static func make(from stats: GlobalStats) -> [Badge] {
        make(streak: stats.bestStreak, runden: stats.quizzesPlayed, fragen: stats.totalAnswers,
             richtige: stats.correctAnswers, falsche: stats.falseAnswers, memberSince: stats.installDate)
    }

    // NEU: Overload für fremde Profile, gespeist aus user_stats
    static func make(from stats: AccountStats?, memberSince: Date) -> [Badge] {
        make(streak: stats?.bestStreak ?? 0, runden: stats?.quizzesPlayed ?? 0, fragen: stats?.totalAnswers ?? 0,
             richtige: stats?.correctAnswers ?? 0, falsche: stats?.falseAnswers ?? 0, memberSince: memberSince)
    }
}
