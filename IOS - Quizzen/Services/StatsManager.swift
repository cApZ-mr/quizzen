//
//  StatsManager.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 11.06.26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Datenmodelle
nonisolated struct DailySnapshot: Codable {
    var date: Date
    var quizzesPlayed: Int
    var questionsAnswered: Int
    var correctAnswers: Int
    var falseAnswers: Int
}

nonisolated struct CategoryStats: Codable {
    var roundsPlayed: Int
    var answeredIDs: Set<String>
    var correctIDs: Set<String>
    var falseIDs: Set<String>

    var answeredCount: Int { answeredIDs.count }

    // PROZENT: Anteil der bearbeiteten Fragen (von der Gesamtanzahl im Quiz)
    func percentFinished(totalQuestions: Int) -> Int {
        totalQuestions == 0 ? 0 : Int((Double(answeredCount) / Double(totalQuestions)) * 100)
    }

    // PROZENT: Richtig beantwortete Fragen (von den beantworteten)
    var percentCorrect: Int {
        answeredCount == 0 ? 0 : Int((Double(correctIDs.count) / Double(answeredCount)) * 100)
    }
}

nonisolated struct GlobalStats: Codable {
    var installDate: Date = Date()

    var totalAnswers: Int = 0
    var correctAnswers: Int = 0
    var falseAnswers: Int = 0
    var quizzesPlayed: Int = 0

    var playTime: TimeInterval = 0

    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var lastPlayedDate: Date?
}



// MARK: - Category StatsManager
class CategoryStatsManager: ObservableObject {
    @AppStorage("categoryRegistryData") private var registryData: Data = Data()
    @Published var categoryRegistry: [String: CategoryStats] = [:] { didSet { saveRegistry() } }

    private let categoryMapping: [String: String] = ["basics": "Allgemeinwissen", "flags": "Flaggen", "games": "Spiele"]

    init() {
        loadRegistry()
        migrateLegacyQuizzes()
    }

    /// Einmalig: Fortschritt der früheren Einzel-Quizze (z. B. „Flaggen (Europa)“)
    /// in das jeweilige Gesamt-Quiz übernehmen. Fragen-IDs sind identisch,
    /// daher werden die Mengen einfach vereinigt und Runden addiert.
    private func migrateLegacyQuizzes() {
        let flagKey = "stats.migratedToQuizCatalog.v1"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: flagKey) }
        guard !categoryRegistry.isEmpty else { return }

        var registry = categoryRegistry
        for definition in QuizCatalog.all {
            let newKey = makeKey(categoryId: definition.categoryId, subCategory: definition.title, quizID: definition.id)
            var merged = registry[newKey] ?? CategoryStats(roundsPlayed: 0, answeredIDs: [], correctIDs: [], falseIDs: [])
            var changed = false

            for legacyId in definition.legacyQuizIds {
                guard let legacy = DataService.loadQuiz(from: legacyId) else { continue }
                let oldKey = makeKey(categoryId: legacy.categoryId, subCategory: legacy.subCategory, quizID: legacy.id)
                guard oldKey != newKey, let old = registry.removeValue(forKey: oldKey) else { continue }
                merged.roundsPlayed += old.roundsPlayed
                merged.answeredIDs.formUnion(old.answeredIDs)
                merged.correctIDs.formUnion(old.correctIDs)
                merged.falseIDs.formUnion(old.falseIDs)
                changed = true
            }
            if changed { registry[newKey] = merged }
        }
        categoryRegistry = registry
        log.info("Quiz-Fortschritt auf neue Quiz-Struktur übertragen")
    }


    private func makeKey(categoryId: String, subCategory: String, quizID: String) -> String {
        let normalizedCategory = categoryMapping[categoryId.lowercased()] ?? subCategory
        return "\(normalizedCategory)_\(quizID)"
    }

    func recordAnswer(questionID: String, isCorrect: Bool, categoryID: String, subCategory: String, quizID: String) {
        let key = makeKey(categoryId: categoryID, subCategory: subCategory, quizID: quizID)
        var stats = categoryRegistry[key] ?? CategoryStats(roundsPlayed: 0, answeredIDs: [], correctIDs: [], falseIDs: [])

        stats.answeredIDs.insert(questionID)
        if isCorrect { stats.correctIDs.insert(questionID) } else { stats.falseIDs.insert(questionID) }
        categoryRegistry[key] = stats
    }

    func startRound(categoryID: String, subCategory: String, quizID: String) {
        let key = makeKey(categoryId: categoryID, subCategory: subCategory, quizID: quizID)
        var stats = categoryRegistry[key] ?? CategoryStats(roundsPlayed: 0, answeredIDs: [], correctIDs: [], falseIDs: [])
        stats.roundsPlayed += 1
        categoryRegistry[key] = stats
    }

    private func saveRegistry() { if let encoded = try? JSONEncoder().encode(categoryRegistry) { registryData = encoded } }
    private func loadRegistry() { if let decoded = try? JSONDecoder().decode([String: CategoryStats].self, from: registryData) { categoryRegistry = decoded } }

    func getStats(for quiz: QuizDetail) -> CategoryStats {
        let key = makeKey(categoryId: quiz.categoryId, subCategory: quiz.subCategory, quizID: quiz.id)

        if let stats = categoryRegistry[key] {
            return stats
        } else {
            return CategoryStats(roundsPlayed: 0, answeredIDs: [], correctIDs: [], falseIDs: [])
        }
    }

    // MARK: - Reset
    func reset() {
        categoryRegistry = [:]
    }
}

// MARK: - Globaler StatsManager
class GlobalStatsManager: ObservableObject {
    @AppStorage("globalStatsData") private var globalStatsData: Data = Data()

    @Published var stats: GlobalStats = GlobalStats() {
        didSet { save() }
    }

    // Bequeme Zugriffe, falls du sie direkt brauchst
    var totalAnswers: Int { stats.totalAnswers }
    var correctAnswers: Int { stats.correctAnswers }
    var falseAnswers: Int { stats.falseAnswers }
    var quizzesPlayed: Int { stats.quizzesPlayed }
    var currentStreak: Int { stats.currentStreak }
    var bestStreak: Int { stats.bestStreak }
    var installDate: Date { stats.installDate }
    var playTime: TimeInterval { stats.playTime }

    private var sessionStart: Date?

    init() {
        load()
        updateStreakIfNeeded()
    }

    // MARK: - Antworten

    func incrementGlobalStats(isCorrect: Bool) {
        stats.totalAnswers += 1
        if isCorrect {
            stats.correctAnswers += 1
        } else {
            stats.falseAnswers += 1
        }
    }

    // MARK: - Runden

    func recordQuizPlayed() {
        stats.quizzesPlayed += 1
        registerActivityToday()
    }

    // MARK: - Spielzeit

    func startSession() {
        sessionStart = Date()
    }

    func endSession() {
        guard let start = sessionStart else { return }
        stats.playTime += Date().timeIntervalSince(start)
        sessionStart = nil
    }

    // MARK: - Streak Logik

    /// Wird beim Spielen aufgerufen, um die Streak zu aktualisieren
    private func registerActivityToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastPlayed = stats.lastPlayedDate else {
            // Erstes Mal überhaupt
            stats.currentStreak = 1
            stats.bestStreak = max(stats.bestStreak, 1)
            stats.lastPlayedDate = today
            return
        }

        let lastPlayedDay = calendar.startOfDay(for: lastPlayed)
        let daysBetween = calendar.dateComponents([.day], from: lastPlayedDay, to: today).day ?? 0

        switch daysBetween {
        case 0:
            // Heute schon gespielt -> nichts ändern
            break
        case 1:
            // Genau ein Tag später -> Streak fortsetzen
            stats.currentStreak += 1
            stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
            stats.lastPlayedDate = today
        default:
            // Streak unterbrochen
            stats.currentStreak = 1
            stats.lastPlayedDate = today
        }
    }

    /// Prüft beim App-Start (und nach dem Server-Sync), ob die Streak wegen
    /// Inaktivität zurückgesetzt werden muss
    func updateStreakIfNeeded() {
        guard let lastPlayed = stats.lastPlayedDate else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastPlayedDay = calendar.startOfDay(for: lastPlayed)
        let daysBetween = calendar.dateComponents([.day], from: lastPlayedDay, to: today).day ?? 0

        if daysBetween > 1 {
            stats.currentStreak = 0
        }
    }

    // MARK: - Persistenz

    private func save() {
        if let encoded = try? JSONEncoder().encode(stats) {
            globalStatsData = encoded
        }
    }

    private func load() {
        if let decoded = try? JSONDecoder().decode(GlobalStats.self, from: globalStatsData) {
            stats = decoded
        } else {
            // Beim allerersten Start: Install-Datum setzen
            stats = GlobalStats(installDate: Date())
        }
    }

    // MARK: - Reset
    func reset() {
        sessionStart = nil
        stats = GlobalStats(installDate: Date())
    }
}

// MARK: - StatsManager
class StatsManager: ObservableObject {
    @Published var categoryManager = CategoryStatsManager()
    @Published var globalManager = GlobalStatsManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        categoryManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        globalManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func getStats(for quiz: QuizDetail) -> CategoryStats {
        return categoryManager.getStats(for: quiz)
    }

    func recordAnswer(questionID: String, isCorrect: Bool, categoryID: String, subCategory: String, quizID: String) {
        categoryManager.recordAnswer(questionID: questionID, isCorrect: isCorrect, categoryID: categoryID, subCategory: subCategory, quizID: quizID)
        globalManager.incrementGlobalStats(isCorrect: isCorrect)
    }

    func startRound(categoryID: String, subCategory: String, quizID: String) {
        categoryManager.startRound(categoryID: categoryID, subCategory: subCategory, quizID: quizID)
        globalManager.recordQuizPlayed()
    }

    // MARK: - Supabase-Sync
    // Ein Aufruf pro abgeschlossenem Quiz (nicht pro Antwort!), sonst
    // gäbe es bei z.B. 20 Fragen 20 unnötige Netzwerk-Calls.

    /// Wird aufgerufen, sobald ein Quiz fertig gespielt wurde (z.B. wenn
    /// QuizViewModel.isFinished auf true wechselt). Speichert zusätzlich
    /// zu den aggregierten Stats auch einen Verlaufs-Eintrag (quiz_attempts).
    func finishQuiz(quiz: QuizDetail, score: Int, maxScore: Int) {
        let currentStats = globalManager.stats
        Task {
            await supabase.saveQuizAttempt(quizId: quiz.id, score: score, maxScore: maxScore)
            await supabase.syncUserStats(currentStats)
        }
    }

    /// Synct NUR die aggregierten Stats, ohne einen quiz_attempts-Eintrag
    /// anzulegen. Dafür gedacht, bei JEDEM Verlassen des Quiz-Screens
    /// aufgerufen zu werden - auch bei Abbruch nach z.B. 5 von 15 Fragen.
    /// So zählt Teilfortschritt auch in der Datenbank, nicht nur lokal.
    func syncStatsOnly() {
        let currentStats = globalManager.stats
        Task {
            await supabase.syncUserStats(currentStats)
        }
    }

    /// Lädt beim Login/App-Start die Server-Stats (Multi-Device-Sync).
    /// Es gewinnt der Stand mit mehr beantworteten Fragen – so gehen weder
    /// offline gespielte Runden noch Fortschritt von anderen Geräten verloren.
    func syncFromServer() async {
        let local = globalManager.stats

        guard let remote = await supabase.loadUserStats() else {
            // Noch keine Server-Zeile (z. B. alter Account): lokalen Stand hochladen.
            if local.totalAnswers > 0 { await supabase.syncUserStats(local) }
            return
        }

        let merged = Self.merge(local: local, remote: remote)
        globalManager.stats = merged
        globalManager.updateStreakIfNeeded()

        if local.totalAnswers > remote.totalAnswers {
            await supabase.syncUserStats(globalManager.stats)
        }
    }

    nonisolated static func merge(local: GlobalStats, remote: GlobalStats) -> GlobalStats {
        var merged = remote.totalAnswers >= local.totalAnswers ? remote : local
        merged.installDate = min(local.installDate, remote.installDate)
        merged.lastPlayedDate = [local.lastPlayedDate, remote.lastPlayedDate].compactMap { $0 }.max()
        merged.bestStreak = max(local.bestStreak, remote.bestStreak)
        return merged
    }

    // MARK: - Reset
    func resetAll() {
        categoryManager.reset()
        globalManager.reset()
    }
}
