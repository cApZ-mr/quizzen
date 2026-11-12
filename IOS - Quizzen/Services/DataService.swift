//
//  DataService.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 29.05.26.
//

import Foundation
import SwiftUI

class DataService {

    /// Lädt eine Quiz-Datei aus dem Bundle (Quelldaten für den QuizCatalog)
    static func loadQuiz(from fileName: String) -> QuizDetail? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            log.error("Datei \(fileName).json wurde nicht gefunden.")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let quiz = try JSONDecoder().decode(QuizDetail.self, from: data)
            return ContentLocalization.isGerman ? quiz : quiz.translated()
        } catch {
            log.error("Fehler beim Decodieren von \(fileName): \(error)")
            return nil
        }
    }

    /// Alle Quizze der App – ein Quiz pro Thema (siehe QuizCatalog).
    /// Wird nur einmal erzeugt und dann gecacht.
    static func loadAllQuizzes() -> [QuizDetail] { allQuizzes }

    private static let allQuizzes: [QuizDetail] = QuizCatalog.all.map(\.baseQuiz)
}

extension QuizDetail {
    /// Fragen und Antworten für die Anzeige übersetzen; die ID bleibt deutsch.
    nonisolated func translated() -> QuizDetail {
        QuizDetail(id: id, categoryId: categoryId, subCategory: subCategory, title: tr(title),
                   description: tr(description), imageName: imageName, difficulty: difficulty,
                   questions: questions.map { $0.translated() }, settings: settings)
    }
}

extension Question {
    nonisolated func translated() -> Question {
        Question(question: tr(question), imageName: imageName,
                 options: options.map { ContentLocalization.tr(option: $0, question: question) },
                 correctAnswerIndex: correctAnswerIndex, promptText: promptText, key: key ?? question)
    }
}
