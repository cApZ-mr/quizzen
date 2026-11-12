//
//  DailyChallenge.swift
//  IOS - Quizzen
//
//  Tageschallenge: Jeden Tag bekommen alle dieselben 10 Fragen aus allen
//  Quizzen (Startwert = Datum). Ein Versuch pro Tag, eigene Bestenliste.
//

import Foundation

enum DailyChallenge {
    static let questionCount = 10
    static let timeLimit = 20
    private static let idPrefix = "Daily-"

    /// Tagesschlüssel, z. B. „2026-11-09“
    static func dateKey(for date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Quiz-ID für Versuche und Bestenliste, z. B. „Daily-2026-11-09“
    static func quizId(for date: Date = .now) -> String { idPrefix + dateKey(for: date) }

    static func isDaily(_ quizId: String) -> Bool { quizId.hasPrefix(idPrefix) }

    // MARK: Erledigt-Status (nur dieses Gerät)

    static func completedScore(for date: Date = .now) -> Int? {
        let key = "daily.score.\(dateKey(for: date))"
        return UserDefaults.standard.object(forKey: key) as? Int
    }

    static func markCompleted(score: Int, for date: Date = .now) {
        UserDefaults.standard.set(score, forKey: "daily.score.\(dateKey(for: date))")
    }

    // MARK: Fragen des Tages

    /// Gleiche Fragen für alle: Startwert aus dem Datum
    static func quiz(for date: Date = .now) -> QuizDetail {
        let key = dateKey(for: date)
        var rng = SeededGenerator(seed: key.unicodeScalars.reduce(UInt64(1469598103934665603)) {
            ($0 ^ UInt64($1.value)) &* 1099511628211
        })

        // Erst Quiz zufällig wählen, dann eine Frage daraus – so kommen alle Themen vor
        var picked: [Question] = []
        var usedIds = Set<String>()
        var attempts = 0
        while picked.count < questionCount && attempts < 200 {
            attempts += 1
            let definition = QuizCatalog.all[Int.random(in: 0..<QuizCatalog.all.count, using: &rng)]
            guard !definition.items.isEmpty else { continue }
            let item = definition.items[Int.random(in: 0..<definition.items.count, using: &rng)]
            guard usedIds.insert(definition.id + item.question.id).inserted else { continue }
            picked.append(definition.makeQuestion(for: item, answerCount: 4, distractors: .similar, using: &rng))
        }

        return QuizDetail(
            id: quizId(for: date), categoryId: "daily", subCategory: "Tageschallenge",
            title: String(localized: "Tageschallenge"), description: String(localized: "10 Fragen aus allen Quizzen – für alle gleich."),
            imageName: "", difficulty: .medium, questions: picked,
            settings: QuizPlaySettings(roundLength: picked.count, timeLimit: timeLimit,
                                       label: date.formatted(.dateTime.day().month(.wide))))
    }
}
