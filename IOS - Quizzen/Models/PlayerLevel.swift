//
//  PlayerLevel.swift
//  IOS - Quizzen
//
//  Level/XP-System: macht Fortschritt im Profil und in der Bestenliste sichtbar.
//

import SwiftUI

nonisolated struct PlayerLevel: Equatable {
    static let xpPerCorrectAnswer = 10
    static let xpPerRound = 25

    let xp: Int

    init(correctAnswers: Int, quizzesPlayed: Int) {
        xp = max(0, correctAnswers) * Self.xpPerCorrectAnswer + max(0, quizzesPlayed) * Self.xpPerRound
    }

    /// XP, die man für Level `n` insgesamt braucht (Level 1 = 0 XP, 2 = 100, 3 = 300, 4 = 600 …).
    static func xpRequired(for level: Int) -> Int {
        50 * level * (level - 1)
    }

    var level: Int {
        var level = 1
        while xp >= Self.xpRequired(for: level + 1) { level += 1 }
        return level
    }

    var xpIntoLevel: Int { xp - Self.xpRequired(for: level) }
    var xpForNextLevel: Int { Self.xpRequired(for: level + 1) - Self.xpRequired(for: level) }
    var progress: Double { Double(xpIntoLevel) / Double(xpForNextLevel) }

    var title: String {
        switch level {
        case ..<3:   String(localized: "Neuling")
        case 3..<6:  String(localized: "Rätselfreund")
        case 6..<10: String(localized: "Wissensjäger")
        case 10..<15: "Quiz-Profi"
        case 15..<25: String(localized: "Quizmeister")
        default:     String(localized: "Legende")
        }
    }

    var color: Color {
        switch level {
        case ..<3:   .gray
        case 3..<6:  .green
        case 6..<10: .blue
        case 10..<15: .purple
        case 15..<25: .orange
        default:     .yellow
        }
    }
}

extension GlobalStats {
    var level: PlayerLevel { PlayerLevel(correctAnswers: correctAnswers, quizzesPlayed: quizzesPlayed) }

    /// Trefferquote in Prozent (0, wenn noch nichts beantwortet)
    var accuracy: Int {
        totalAnswers == 0 ? 0 : Int((Double(correctAnswers) / Double(totalAnswers) * 100).rounded())
    }
}
