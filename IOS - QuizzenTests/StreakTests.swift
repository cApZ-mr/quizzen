//
//  StreakTests.swift
//  IOS - QuizzenTests
//

import Foundation
import Testing
@testable import IOS___Quizzen

@Suite("Streak-Plausibilität")
@MainActor
struct StreakTests {
    @Test func maxTageZaehltHeuteMit() {
        let cal = Calendar.current
        let now = Date()
        #expect(GlobalStatsManager.maxStreakDays(since: now, now: now) == 1)
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        #expect(GlobalStatsManager.maxStreakDays(since: yesterday, now: now) == 2)
    }

    @Test func rekordWirdAufKontoalterBegrenzt() {
        let manager = GlobalStatsManager()
        let original = manager.stats
        defer { manager.stats = original }

        manager.stats.bestStreak = 3
        manager.stats.currentStreak = 3
        let created = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(manager.clampStreaks(accountCreated: created))
        #expect(manager.stats.bestStreak == 2)
        #expect(manager.stats.currentStreak == 2)
        #expect(!manager.clampStreaks(accountCreated: created))
    }
}
