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
            return try JSONDecoder().decode(QuizDetail.self, from: data)
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
