//
//  DailyChallengeTests.swift
//  IOS - QuizzenTests
//

import Foundation
import Testing
@testable import IOS___Quizzen

@Suite("Tageschallenge")
struct DailyChallengeTests {
    private let day = Date(timeIntervalSince1970: 1_794_200_000)

    @Test("Für alle gleich: gleiches Datum ergibt dieselben Fragen und Antworten")
    func deterministic() {
        let a = DailyChallenge.quiz(for: day)
        let b = DailyChallenge.quiz(for: day)
        #expect(a.questions.map(\.question) == b.questions.map(\.question))
        #expect(a.questions.map(\.options) == b.questions.map(\.options))
        #expect(a.id == DailyChallenge.quizId(for: day))
    }

    @Test("10 verschiedene, gültige Fragen mit 20 s Zeitlimit")
    func validRound() {
        let quiz = DailyChallenge.quiz(for: day)
        #expect(quiz.questions.count == DailyChallenge.questionCount)
        #expect(quiz.settings?.timeLimit == DailyChallenge.timeLimit)
        #expect(Set(quiz.questions.map(\.question)).count == quiz.questions.count)
        for question in quiz.questions {
            #expect(question.options.indices.contains(question.correctAnswerIndex))
            #expect(Set(question.options).count == question.options.count)
        }
    }

    @Test("Kein Fragetext verrät die Lösung – über 60 Tage")
    func noLeaksAcrossDays() {
        for offset in 0..<60 {
            let quiz = DailyChallenge.quiz(for: day.addingTimeInterval(Double(offset) * 86_400))
            for question in quiz.questions {
                #expect(question.prompt(quizId: quiz.id) != question.options[question.correctAnswerIndex])
            }
        }
    }

    @Test("Andere Tage, andere Fragen")
    func changesDaily() {
        let today = DailyChallenge.quiz(for: day).questions.map(\.question)
        let tomorrow = DailyChallenge.quiz(for: day.addingTimeInterval(86_400)).questions.map(\.question)
        #expect(today != tomorrow)
    }
}
