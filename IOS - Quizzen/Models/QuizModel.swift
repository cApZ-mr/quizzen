//
//  Quiz.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 29.05.26.
//

import Foundation

// MARK: - Difficulty

nonisolated enum Difficulty: String, Codable, CaseIterable {
    case easy = "Leicht"
    case medium = "Mittel"
    case hard = "Schwer"

    /// Angezeigter Name (rawValue bleibt deutsch – steht so in den Quiz-Dateien)
    var title: String {
        switch self {
        case .easy: String(localized: "Leicht")
        case .medium: String(localized: "Mittel")
        case .hard: String(localized: "Schwer")
        }
    }
}

// MARK: - QuizDetail
// Einzige Quelle für ein Quiz: eine Datei, alle Daten drin.

nonisolated struct QuizDetail: Identifiable, Codable {
    let id: String
    let categoryId: String
    let subCategory: String
    let title: String
    let description: String
    let imageName: String
    let difficulty: Difficulty
    let questions: [Question]
    /// Nur bei generierten Runden (z. B. Flaggen-Presets) gesetzt
    var settings: QuizPlaySettings? = nil

    // Kein gespeichertes questionCount-Feld -> wird immer live berechnet.
    var questionCount: Int { questions.count }

}

/// Spiel-Einstellungen einer generierten Runde
nonisolated struct QuizPlaySettings: Codable, Hashable {
    /// Anzahl Fragen pro Runde (nil = Standard: max. 15)
    var roundLength: Int?
    /// Sekunden pro Frage (nil = kein Zeitlimit)
    var timeLimit: Int?
    /// Anzeigename, z. B. „Kenner“
    var label: String?
}

// MARK: - Question

nonisolated struct Question: Codable, Identifiable {
    /// Stabile ID = deutscher Fragetext (auch wenn `question` übersetzt ist).
    /// Fortschritt, Tageschallenge und Duelle hängen an dieser ID.
    var id: String { key ?? question }
    let question: String
    let imageName: String?
    let options: [String]
    let correctAnswerIndex: Int
    /// Eigener Fragetext für Bild-Fragen außerhalb ihres Quiz (z. B. Tageschallenge)
    var promptText: String? = nil
    /// Deutscher Originaltext, falls `question` übersetzt wurde
    var key: String? = nil
}

// MARK: - Angezeigter Fragetext

extension Question {
    /// Text, der beim Spielen über/unter dem Bild steht.
    /// Achtung: Bei Bild-Fragen enthält `question` die LÖSUNG (dient als ID),
    /// darf also während des Spiels nie angezeigt werden.
    func prompt(quizId: String) -> String {
        if let promptText { return promptText }
        guard imageName != nil else { return question }
        if quizId.hasPrefix("Flags") { return String(localized: "Welches Land hat diese Flagge?") }
        return String(localized: "Was ist auf dem Bild zu sehen?")
    }
}

extension QuizDetail {
    /// Definition mit Presets/Filtern (jedes Quiz der App hat eine)
    @MainActor var definition: QuizDefinition? { QuizCatalog.definition(for: id) }
}
