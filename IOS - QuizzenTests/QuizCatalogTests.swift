//
//  QuizCatalogTests.swift
//  IOS - QuizzenTests
//
//  Presets, Filter und Runden-Erzeugung aller Quizze.
//

import Foundation
import Testing
@testable import IOS___Quizzen

@Suite("Quiz-Presets")
struct QuizCatalogTests {

    @Test("Jedes Preset erzeugt eine gültige Runde", arguments: allQuizIds, ["easy", "medium", "hard", "extreme"])
    func presetsBuildValidRounds(quizId: String, presetId: String) throws {
        let definition = try #require(QuizCatalog.definition(for: quizId))
        let preset = try #require(definition.presets.first { $0.id == presetId })
        let config = try #require(preset.config)
        let quiz = definition.build(config: config, label: preset.name)

        let available = definition.availableCount(for: config)
        let expected = config.questionCount == 0 ? available : min(config.questionCount, available)
        #expect(expected > 0, "\(quizId)/\(preset.name) hat keine Fragen")
        #expect(quiz.questions.count == expected)
        #expect(quiz.settings?.timeLimit == config.timeLimit)
        #expect(definition.answerChoices.contains(config.answerCount) || config.answerCount <= definition.maxAnswers)

        for question in quiz.questions {
            #expect(question.options.count == min(config.answerCount, definition.maxAnswers))
            #expect(Set(question.options).count == question.options.count, "doppelte Antwort bei \(question.question)")
            let original = try #require(definition.items.first { $0.question.id == question.id })
            #expect(question.options[question.correctAnswerIndex] == original.answer)
        }
    }

    @Test("Regionen-Filter und „Nur unbekannte“ werden beachtet")
    func filtersApply() throws {
        let flags = QuizCatalog.flags
        var config = QuizConfig(selections: ["region": ["oceania"]], questionCount: 0, answerCount: 2)
        let oceania = Set(flags.items.filter { $0.tags["region"] == "oceania" }.map(\.question.id))
        #expect(Set(flags.build(config: config, label: "").questions.map(\.id)) == oceania)

        config.onlyUnknown = true
        let known: Set<String> = [try #require(oceania.first)]
        let round = flags.build(config: config, label: "", knownQuestions: known)
        #expect(round.questions.count == oceania.count - 1)
        #expect(!round.questions.contains { known.contains($0.id) })
    }

    @Test("Hauptstädte: Fragerichtung bestimmt die Art der Antworten")
    func capitalsDirection() {
        let capitals = QuizCatalog.capitals
        let config = QuizConfig(selections: ["direction": ["toCapital"]], questionCount: 0, answerCount: 6, distractors: .random)
        let allCapitals = Set(capitals.items.filter { $0.answerType == "capital" }.map(\.answer))
        let round = capitals.build(config: config, label: "")
        #expect(round.questions.allSatisfy { $0.question.hasPrefix("Was ist die Hauptstadt") })
        #expect(round.questions.allSatisfy { Set($0.options).isSubset(of: allCapitals) },
                "Bei „Land → Hauptstadt“ dürfen nur Hauptstädte als Antworten vorkommen")
    }

    @Test("„Ähnlich“ nutzt die handverlesenen Antworten")
    func similarDistractorsPreferCurated() throws {
        let flags = QuizCatalog.flags
        let config = QuizConfig(selections: ["region": ["europe"]], questionCount: 0, answerCount: 4, distractors: .similar)
        let round = flags.build(config: config, label: "")
        let albania = try #require(round.questions.first { $0.id == "Albanien" })
        let curated = Set(try #require(flags.items.first { $0.question.id == "Albanien" }).curatedDistractors)
        #expect(Set(albania.options.filter { $0 != "Albanien" }) == curated)
    }

    @Test("Quizze ohne typisierte Antworten bieten max. 4 Antworten")
    func untypedQuizzesLimitAnswers() {
        #expect(QuizCatalog.basics.answerChoices == [2, 3, 4])
        #expect(QuizCatalog.flags.answerChoices == [2, 4, 6])
        let round = QuizCatalog.basics.build(config: QuizConfig(questionCount: 10, answerCount: 6), label: "")
        #expect(round.questions.allSatisfy { $0.options.count == 4 })
    }

    @Test("Alle bekannten Flaggen existieren")
    func wellKnownFlagsExist() {
        let codes = Set(QuizCatalog.flags.items.compactMap(\.question.imageName))
        #expect(QuizCatalog.wellKnownFlags.isSubset(of: codes), "Fehlend: \(QuizCatalog.wellKnownFlags.subtracting(codes))")
    }

    @Test("Lobby-Runde: gleicher Startwert erzeugt auf allen Geräten dieselben Antworten", arguments: allQuizIds)
    func duelQuestionsAreDeterministic(quizId: String) throws {
        let definition = try #require(QuizCatalog.definition(for: quizId))
        let lobbyId = UUID()
        for index in 0..<min(5, definition.items.count) {
            let seed = LobbySession.seed(lobbyId: lobbyId, round: 1, index: index)
            var deviceA = SeededGenerator(seed: seed)
            var deviceB = SeededGenerator(seed: seed)
            let a = definition.makeQuestion(for: definition.items[index], answerCount: 4, distractors: .random, using: &deviceA)
            let b = definition.makeQuestion(for: definition.items[index], answerCount: 4, distractors: .random, using: &deviceB)
            #expect(a.options == b.options)
            #expect(a.correctAnswerIndex == b.correctAnswerIndex)
        }
    }
}
