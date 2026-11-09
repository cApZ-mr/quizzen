//
//  QuizPlayView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 03.06.26.
//

import Foundation
import SwiftUI

// MARK: - QuizPlay View
struct QuizPlayView: View {
    @StateObject private var viewModel: QuizViewModel
    @EnvironmentObject var statsManager: StatsManager

    @Environment(\.dismiss) var dismiss
    let currentQuiz: QuizDetail

    @State private var showReportSheet = false


    init(currentQuiz: QuizDetail, statsManager: StatsManager, makeRound: (() -> QuizDetail)? = nil) {
        self.currentQuiz = currentQuiz
        _viewModel = StateObject(
            wrappedValue: QuizViewModel(
                quiz: currentQuiz,
                statsManager: statsManager,
                makeRound: makeRound
            )
        )
    }


    // MARK: Berechnungen für den Endscreen
    var procentScore: Int {
        guard viewModel.maxQuestions > 0 else { return 0 }
        let calculation = (Double(viewModel.score) * 100) / Double(viewModel.maxQuestions)
        return Int(calculation.rounded())
    }

    var scoreColor: Color {
        switch procentScore {
        case 100: return .green
        case 80..<100: return Color.green.opacity(0.6)
        case 50..<80: return .orange
        case 25..<50: return Color.orange.opacity(0.8)
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading) {
                    Text(viewModel.quiz.settings?.label.map { "\(viewModel.quiz.title) · \($0)" } ?? viewModel.quiz.title)
                        .font(.caption).bold().foregroundColor(.secondary)
                    Text("\(viewModel.currentIndex + 1) / \(viewModel.maxQuestions)").font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Punkte").font(.caption).foregroundColor(.secondary)
                    Text("\(viewModel.score)").font(.headline).bold().foregroundColor(Color.brand)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
            .padding(.bottom, viewModel.isFinished ? 20 : 10)

            if !viewModel.isFinished {
                ProgressView(value: Double(viewModel.currentIndex + (viewModel.isConfirmed ? 1 : 0)),
                             total: Double(max(viewModel.maxQuestions, 1)))
                    .tint(Color.brandLight)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 16)
                    .animation(.easeInOut, value: viewModel.currentIndex)
                    .accessibilityLabel("Frage \(viewModel.currentIndex + 1) von \(viewModel.maxQuestions)")

                if let remaining = viewModel.timeRemaining, let limit = viewModel.timeLimit {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                        ProgressView(value: remaining, total: Double(limit))
                            .tint(remaining <= 3 ? .red : .orange)
                        Text("\(Int(remaining.rounded(.up))) s")
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(remaining <= 3 ? .red : .orange)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 12)
                    .opacity(viewModel.isConfirmed ? 0.4 : 1)
                    .accessibilityLabel("Noch \(Int(remaining)) Sekunden")
                }
            }

            if viewModel.isFinished {
                QuizResultView(
                    viewModel: viewModel,
                    procentScore: procentScore,
                    scoreColor: scoreColor
                )
            } else {
                QuestionHeaderView(question: viewModel.currentQuestion, quizId: currentQuiz.id) {
                    showReportSheet = true
                }
                .sheet(isPresented: $showReportSheet) {
                    ReportQuizView(quiz: currentQuiz, viewModel: viewModel)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Antwortmöglichkeiten
                VStack(spacing: 12) {
                    if viewModel.didTimeOut {
                        Label("Zeit abgelaufen!", systemImage: "clock.badge.xmark")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .transition(.scale.combined(with: .opacity))
                    }
                    ForEach(viewModel.displayOptions) { option in
                        Button(action: {
                            viewModel.selectOption(option)
                            UISelectionFeedbackGenerator().selectionChanged()
                        }) {
                            HStack(spacing: 10) {
                                Text(option.text)
                                    .font(.system(size: 18, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                if let icon = resultIcon(for: option) {
                                    Image(systemName: icon)
                                        .font(.title3)
                                }
                            }
                            .padding(18)
                            .background(buttonColor(for: option))
                            .foregroundColor(buttonTextColor(for: option))
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(option.id == viewModel.selectedOptionId && !viewModel.isConfirmed
                                            ? Color.brandLight : .clear, lineWidth: 2)
                            )
                        }
                        .disabled(viewModel.isConfirmed)
                        .accessibilityAddTraits(option.id == viewModel.selectedOptionId ? .isSelected : [])
                    }

                    // Action Button
                    if viewModel.selectedOptionId != nil, !viewModel.isConfirmed {
                        Button(action: {
                            viewModel.confirmAnswer()
                            let wasCorrect = viewModel.answerLog.last?.isCorrect ?? false
                            UINotificationFeedbackGenerator().notificationOccurred(wasCorrect ? .success : .error)
                        }) {
                            Text("Antwort bestätigen")
                                .font(.headline)
                                .frame(maxWidth: .infinity).padding(18)
                                .background(Color.brand)
                                .foregroundColor(.white)
                                .cornerRadius(18)
                        }
                    } else if viewModel.isConfirmed {
                        Button(action: { viewModel.nextQuestion() }) {
                            Text(viewModel.currentIndex + 1 >= viewModel.maxQuestions ? "Ergebnis anzeigen" : "Nächste Frage")
                                .font(.headline)
                                .frame(maxWidth: .infinity).padding(18)
                                .background(Color.brand)
                                .foregroundColor(.white)
                                .cornerRadius(18)
                        }
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(30)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            statsManager.globalManager.startSession()
        }
        .onDisappear {
            // Spielzeit erfassen, dann synchronisieren
            statsManager.globalManager.endSession()
            statsManager.syncStatsOnly()
        }
    }



    func buttonColor(for option: QuizOption) -> Color {
        if viewModel.isConfirmed {
            if option.isCorrect { return .green }
            if option.id == viewModel.selectedOptionId && !option.isCorrect { return .red }
        } else {
            return option.id == viewModel.selectedOptionId ? Color.blue.opacity(0.3) : Color(UIColor.systemBackground)
        }
        return Color(UIColor.systemBackground)
    }

    func buttonTextColor(for option: QuizOption) -> Color {
        guard viewModel.isConfirmed else { return .primary }
        let isHighlighted = option.isCorrect || option.id == viewModel.selectedOptionId
        return isHighlighted ? .white : .secondary
    }

    /// Richtig/Falsch nicht nur über Farbe zeigen (Barrierefreiheit)
    func resultIcon(for option: QuizOption) -> String? {
        guard viewModel.isConfirmed else { return nil }
        if option.isCorrect { return "checkmark.circle.fill" }
        if option.id == viewModel.selectedOptionId { return "xmark.circle.fill" }
        return nil
    }

}

// MARK: - Frage (Bild oder Text) + Melden-Button
private struct QuestionHeaderView: View {
    let question: Question
    let quizId: String
    let onReport: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                if let imageName = question.imageName, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .accessibilityHidden(true)
                }
                Text(question.prompt(quizId: quizId))
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(cardBackground)

            Button(action: onReport) {
                Image(systemName: "exclamationmark.bubble")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.brand)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Frage melden")
            .offset(x: 10, y: -10)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(UIColor.secondarySystemBackground))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
