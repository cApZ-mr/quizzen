//
//  QuizLogicModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 03.06.26.
//

import Foundation
import SwiftUI
import Combine

/// Protokoll einer beantworteten Frage (für die Auswertung am Ende).
struct AnsweredQuestion: Identifiable {
    let id = UUID()
    let question: Question
    let chosenAnswer: String
    let correctAnswer: String
    var isCorrect: Bool { chosenAnswer == correctAnswer }
}

struct QuizOption: Identifiable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
}

class QuizViewModel: ObservableObject {
    
    let statsManager: StatsManager
    
    @Published var quiz: QuizDetail
    @Published var currentIndex = 0
    
    private var shuffledQuestions: [Question]
    
    @Published var score = 0
    @Published var isFinished = false
    @Published var displayOptions: [QuizOption] = []
    @Published var selectedOptionId: UUID? = nil
    @Published var isConfirmed = false
    @Published private(set) var answerLog: [AnsweredQuestion] = []
    /// Restzeit der aktuellen Frage (nil = ohne Zeitlimit)
    @Published private(set) var timeRemaining: Double?
    @Published private(set) var didTimeOut = false

    /// Erzeugt bei „Nochmal“ eine neue Runde (generierte Quizze wie Flaggen)
    private let makeRound: (() -> QuizDetail)?
    private var timerTask: Task<Void, Never>?

    var timeLimit: Int? { quiz.settings?.timeLimit }

    /// XP, die diese Runde eingebracht hat (siehe PlayerLevel)
    var earnedXP: Int {
        score * PlayerLevel.xpPerCorrectAnswer + (isFinished ? PlayerLevel.xpPerRound : 0)
    }
    
    var currentQuestion: Question {
        shuffledQuestions[currentIndex]
    }
    
 
    var maxQuestions: Int {
        min(quiz.questions.count, quiz.settings?.roundLength ?? 15)
    }

    init(quiz: QuizDetail, statsManager: StatsManager, makeRound: (() -> QuizDetail)? = nil) {
        self.quiz = quiz
        self.statsManager = statsManager
        self.makeRound = makeRound
        self.shuffledQuestions = quiz.questions.shuffled()

        prepareQuestion()
    }
    
    
    func prepareQuestion() {
        guard currentIndex < maxQuestions else {
            finishQuiz()
            return
        }
        
        let question = currentQuestion
        
        displayOptions = question.options.enumerated().map { index, text in
            QuizOption(text: text, isCorrect: index == question.correctAnswerIndex)
        }.shuffled()
        
        selectedOptionId = nil
        isConfirmed = false
        didTimeOut = false
        startTimer()
    }

    // MARK: - Zeitlimit

    private func startTimer() {
        timerTask?.cancel()
        guard let limit = timeLimit else { timeRemaining = nil; return }
        let deadline = Date().addingTimeInterval(TimeInterval(limit))
        timeRemaining = Double(limit)
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                let remaining = max(0, deadline.timeIntervalSinceNow)
                self.timeRemaining = remaining
                if remaining <= 0 {
                    self.timeOut()
                    return
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Zeit abgelaufen: zählt als falsch, Lösung wird gezeigt
    private func timeOut() {
        guard !isConfirmed, !isFinished else { return }
        isConfirmed = true
        didTimeOut = true
        selectedOptionId = nil
        let correctText = displayOptions.first(where: \.isCorrect)?.text ?? ""
        answerLog.append(AnsweredQuestion(question: currentQuestion,
                                          chosenAnswer: String(localized: "Zeit abgelaufen"),
                                          correctAnswer: correctText))
        statsManager.recordAnswer(questionID: currentQuestion.id, isCorrect: false,
                                  categoryID: quiz.categoryId, subCategory: quiz.subCategory, quizID: quiz.id)
    }
    
    func selectOption(_ option: QuizOption) {
        guard !isConfirmed else { return }
        selectedOptionId = option.id
    }
    
    func confirmAnswer() {
        guard let selectedId = selectedOptionId, !isConfirmed else { return }
        isConfirmed = true
        stopTimer()
        
        if let selectedOption = displayOptions.first(where: { $0.id == selectedId }) {
            
            if selectedOption.isCorrect {
                score += 1
            }

            let correctText = displayOptions.first(where: \.isCorrect)?.text ?? ""
            answerLog.append(AnsweredQuestion(question: currentQuestion,
                                              chosenAnswer: selectedOption.text,
                                              correctAnswer: correctText))
            
            statsManager.recordAnswer(
                questionID: currentQuestion.id,
                isCorrect: selectedOption.isCorrect,
                categoryID: quiz.categoryId,
                subCategory: quiz.subCategory,
                quizID: quiz.id
            )
        }
    }
    
    func nextQuestion() {
        if currentIndex < maxQuestions - 1 {
            currentIndex += 1
            prepareQuestion()
        } else {
            finishQuiz()
        }
    }
    
    /// Neue Runde mit frisch gemischten Fragen
    func restart() {
        if let makeRound { quiz = makeRound() }
        shuffledQuestions = quiz.questions.shuffled()
        currentIndex = 0
        score = 0
        answerLog = []
        isFinished = false
        prepareQuestion()
    }

    func finishQuiz() {
        guard !isFinished else { return }   // nie doppelt zählen
        isFinished = true
        stopTimer()

        statsManager.startRound(
            categoryID: quiz.categoryId,
            subCategory: quiz.subCategory,
            quizID: quiz.id
        )
        // Speichert den Versuch in quiz_attempts und synct die Stats.
        statsManager.finishQuiz(quiz: quiz, score: score, maxScore: maxQuestions)
        if DailyChallenge.isDaily(quiz.id) { DailyChallenge.markCompleted(score: score) }
        StreakReminder.reschedule(stats: statsManager.globalManager.stats)
    }
}
