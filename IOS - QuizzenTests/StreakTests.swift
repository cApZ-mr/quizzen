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

    /// Gestern gespielt -> die Streak bleibt heute noch den ganzen Tag stehen,
    /// auch wenn noch nicht erneut gespielt wurde.
    @Test func streakBleibtAmFolgetagErhalten() {
        let manager = GlobalStatsManager()
        let original = manager.stats
        defer { manager.stats = original }

        manager.stats.currentStreak = 5
        manager.stats.lastPlayedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        manager.updateStreakIfNeeded()
        #expect(manager.stats.currentStreak == 5)
    }

    /// Erst wenn ein ganzer Tag komplett ohne Quiz vergangen ist (zwei Tage
    /// seit dem letzten Mal), wird die Streak zurückgesetzt.
    @Test func streakResetErstNachEinemKomplettVerpasstenTag() {
        let manager = GlobalStatsManager()
        let original = manager.stats
        defer { manager.stats = original }

        manager.stats.currentStreak = 5
        manager.stats.lastPlayedDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        manager.updateStreakIfNeeded()
        #expect(manager.stats.currentStreak == 0)
    }

    /// Spielt man am Folgetag doch noch, geht die Streak nahtlos weiter.
    @Test func streakSetztSichBeiSpielAmFolgetagFort() {
        let manager = GlobalStatsManager()
        let original = manager.stats
        defer { manager.stats = original }

        manager.stats.currentStreak = 3
        manager.stats.bestStreak = 3
        manager.stats.lastPlayedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        manager.recordQuizPlayed()
        #expect(manager.stats.currentStreak == 4)
    }

    /// Nach einem komplett verpassten Tag beginnt beim nächsten Spiel eine
    /// neue Streak bei 1, statt direkt weiterzuzählen.
    @Test func streakBeginntNachPauseNeuBeiEins() {
        let manager = GlobalStatsManager()
        let original = manager.stats
        defer { manager.stats = original }

        manager.stats.currentStreak = 3
        manager.stats.bestStreak = 3
        manager.stats.lastPlayedDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        manager.recordQuizPlayed()
        #expect(manager.stats.currentStreak == 1)
    }
}
