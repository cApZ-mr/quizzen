//
//  QuizDataTests.swift
//  IOS - QuizzenTests
//
//  Prüft die Quiz-Daten aller Quizze im Katalog.
//

import Testing
@testable import IOS___Quizzen

/// Feste Liste für parametrisierte Tests (Argumente laufen außerhalb des Main Actors)
nonisolated let allQuizIds = ["Flags", "Capitals", "Aviation", "Basics", "History", "Science", "Movies", "HarryPotter", "Sports"]

@Suite("Quiz-Daten")
struct QuizDataTests {

    @Test("Jedes Quiz hat Fragen und eine eindeutige ID")
    func catalogIsComplete() {
        let ids = QuizCatalog.all.map(\.id)
        #expect(ids == allQuizIds)
        #expect(DataService.loadAllQuizzes().map(\.id) == ids)
        for definition in QuizCatalog.all {
            #expect(!definition.items.isEmpty, "\(definition.id) hat keine Fragen")
            #expect(definition.presets.contains { $0.level == .custom }, "\(definition.id) ohne „Eigene“")
        }
    }

    @Test("Jedes Quiz gehört zu genau einem Themenbereich")
    func everyQuizHasOneCategory() {
        let assigned = QuizCatalog.categories.flatMap { $0.quizzes.map(\.id) }
        #expect(assigned.count == Set(assigned).count, "Quiz in mehreren Bereichen")
        #expect(Set(assigned) == Set(allQuizIds))
        #expect(QuizCatalog.categories.allSatisfy { !$0.quizzes.isEmpty })
    }

    @Test("Bekannte Fragen-Zahlen", arguments: [("Basics", 226), ("Flags", 197), ("Capitals", 393), ("History", 50), ("Science", 49),
                                                  ("Sports", 36), ("Movies", 36), ("HarryPotter", 61), ("Aviation", 148)])
    func expectedPoolSizes(id: String, count: Int) {
        #expect(QuizCatalog.definition(for: id)?.items.count == count)
    }

    @Test("Jede Frage ist gültig und pro Quiz eindeutig", arguments: allQuizIds)
    func questionsAreValid(quizId: String) throws {
        let definition = try #require(QuizCatalog.definition(for: quizId))
        var seen = Set<String>()
        for item in definition.items {
            let question = item.question
            #expect(seen.insert(question.id).inserted, "\(quizId): doppelte Frage „\(question.question)“")
            #expect(question.options.count >= 2)
            #expect(question.options.indices.contains(question.correctAnswerIndex))
            #expect(Set(question.options).count == question.options.count, "\(quizId): doppelte Antwort bei „\(question.question)“")
        }
    }

    @Test("Jede Filter-Option hat Fragen, jede Frage ist zugeordnet", arguments: allQuizIds)
    func filtersCoverItems(quizId: String) throws {
        let definition = try #require(QuizCatalog.definition(for: quizId))
        for filter in definition.filters {
            for option in filter.options {
                #expect(definition.items.contains { $0.tags[filter.id] == option.id }, "\(quizId): „\(option.name)“ ist leer")
            }
            #expect(definition.items.allSatisfy { $0.tags[filter.id] != nil }, "\(quizId): Frage ohne \(filter.title)")
        }
    }

    @Test("Angezeigter Fragetext verrät nie die Lösung")
    func promptNeverRevealsAnswer() {
        for quiz in DataService.loadAllQuizzes() {
            for question in quiz.questions {
                let prompt = question.prompt(quizId: quiz.id)
                let answer = question.options[question.correctAnswerIndex]
                #expect(prompt != answer, "\(quiz.id): Frage zeigt die Lösung „\(answer)“")
            }
        }
    }
}
