//
//  LogicTests.swift
//  IOS - QuizzenTests
//

import Foundation
import Testing
@testable import IOS___Quizzen

@Suite("Versionsvergleich")
struct VersionTests {
    @Test(arguments: [
        ("1.10.0", "1.9.3", true),   // numerisch, nicht alphabetisch
        ("2.0", "1.9.3", true),
        ("1.9.3", "1.9.3", false),
        ("1.9.2", "1.9.3", false),   // Store älter als lokaler Build (z. B. TestFlight)
    ])
    func newer(store: String, local: String, expected: Bool) {
        #expect(AppVersionService.isVersion(store, newerThan: local) == expected)
    }
}

@Suite("Stats-Merge (Multi-Device-Sync)")
struct StatsMergeTests {

    private func stats(answers: Int, best: Int = 0, install: Date = .now, lastPlayed: Date? = nil) -> GlobalStats {
        var s = GlobalStats()
        s.totalAnswers = answers
        s.correctAnswers = answers
        s.bestStreak = best
        s.installDate = install
        s.lastPlayedDate = lastPlayed
        return s
    }

    @Test("Server mit mehr Antworten gewinnt")
    func remoteWins() {
        let merged = StatsManager.merge(local: stats(answers: 5), remote: stats(answers: 50))
        #expect(merged.totalAnswers == 50)
    }

    @Test("Lokal mit mehr Antworten gewinnt (offline gespielt)")
    func localWins() {
        let merged = StatsManager.merge(local: stats(answers: 80), remote: stats(answers: 50))
        #expect(merged.totalAnswers == 80)
    }

    @Test("Frühestes Installationsdatum, neuestes Spieldatum, beste Streak bleiben erhalten")
    func keepsBestOfBoth() {
        let old = Date(timeIntervalSince1970: 1_000)
        let recent = Date(timeIntervalSince1970: 9_000)
        let merged = StatsManager.merge(
            local: stats(answers: 1, best: 7, install: .now, lastPlayed: recent),
            remote: stats(answers: 10, best: 3, install: old, lastPlayed: nil)
        )
        #expect(merged.installDate == old)
        #expect(merged.lastPlayedDate == recent)
        #expect(merged.bestStreak == 7)
    }
}

@Suite("Kategorie-Statistik")
struct CategoryStatsTests {
    @Test func percentages() {
        let stats = CategoryStats(roundsPlayed: 1,
                                  answeredIDs: ["a", "b", "c", "d"],
                                  correctIDs: ["a", "b", "c"],
                                  falseIDs: ["d"])
        #expect(stats.percentFinished(totalQuestions: 8) == 50)
        #expect(stats.percentCorrect == 75)
        #expect(stats.percentFinished(totalQuestions: 0) == 0)
    }
}

@Suite("Level-System")
struct PlayerLevelTests {
    @Test func startsAtLevelOne() {
        let level = PlayerLevel(correctAnswers: 0, quizzesPlayed: 0)
        #expect(level.level == 1)
        #expect(level.progress == 0)
    }

    @Test("Schwellen: L2 = 100 XP, L3 = 300 XP")
    func thresholds() {
        #expect(PlayerLevel(correctAnswers: 10, quizzesPlayed: 0).level == 2)   // 100 XP
        #expect(PlayerLevel(correctAnswers: 29, quizzesPlayed: 0).level == 2)   // 290 XP
        #expect(PlayerLevel(correctAnswers: 30, quizzesPlayed: 0).level == 3)   // 300 XP
    }

    @Test func progressStaysInRange() {
        for answers in stride(from: 0, through: 5_000, by: 37) {
            let level = PlayerLevel(correctAnswers: answers, quizzesPlayed: answers / 10)
            #expect(level.progress >= 0 && level.progress < 1)
        }
    }
}

@Suite("Bestenliste")
struct LeaderboardRankingTests {
    private func account(_ name: String) -> Account {
        Account(id: UUID(), username: name, avatarUrl: nil, country: nil, createdAt: .now)
    }

    @Test("Gleichstand teilt sich den Platz (1, 2, 2, 4)")
    func tiesShareRank() {
        let entries = LeaderboardEntry.ranked([(account("a"), 50), (account("b"), 30), (account("c"), 30), (account("d"), 10)])
        #expect(entries.map { $0.rank } == [1, 2, 2, 4])
    }
}

@Suite("Duell")
struct DuelTests {
    private struct FakeError: Error, CustomStringConvertible { let description: String }

    @Test("Server-Fehler werden verständlich übersetzt")
    func errorMapping() {
        #expect(LobbyError.from(FakeError(description: "P0001: code_not_found")).errorDescription
                == LobbyError.codeNotFound.errorDescription)
        #expect(LobbyError.from(FakeError(description: "lobby_full")).errorDescription
                == LobbyError.lobbyFull.errorDescription)
        #expect(LobbyError.from(FakeError(description: "PGRST202 Could not find the function")).errorDescription
                == LobbyError.serverNotReady.errorDescription)
    }

    @Test("Gemischte Antworten sind für beide Spieler gleich (fester Seed)")
    func seededShuffleIsDeterministic() {
        var a = SeededRandom(seed: 1234)
        var b = SeededRandom(seed: 1234)
        #expect((0..<20).map { _ in a.next() } == (0..<20).map { _ in b.next() })
    }
}
