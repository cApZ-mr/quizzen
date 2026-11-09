//
//  QuizResultView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 19.06.26.
//

import SwiftUI

struct QuizResultView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var statsManager: StatsManager

    @ObservedObject var viewModel: QuizViewModel
    let procentScore: Int
    let scoreColor: Color

    @State private var animatedProgress: CGFloat = 0
    @State private var showMistakes = false

    private var score: Int { viewModel.score }
    private var maxQuestions: Int { viewModel.maxQuestions }
    private var mistakes: [AnsweredQuestion] { viewModel.answerLog.filter { !$0.isCorrect } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                scoreRing
                    .padding(.top, 8)

                Text(getFeedback(for: Double(procentScore)))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    StatBox(title: "Richtig", value: score, icon: "checkmark", color: .green)
                    StatBox(title: "Fehler", value: maxQuestions - score, icon: "xmark", color: .red)
                    StatBox(title: "XP", value: viewModel.earnedXP, icon: "star.fill", color: .yellow)
                }
                .padding(.horizontal)

                levelProgress

                if !mistakes.isEmpty {
                    mistakesSection
                }
            }
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) { actions }
        .onAppear {
            withAnimation(.spring(duration: 1.0).delay(0.2)) {
                animatedProgress = CGFloat(procentScore) / 100
            }
            UINotificationFeedbackGenerator().notificationOccurred(procentScore >= 50 ? .success : .warning)
        }
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(procentScore) %")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("\(score) von \(maxQuestions) richtig")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 190, height: 190)
        .accessibilityElement(children: .combine)
    }

    private var levelProgress: some View {
        let level = statsManager.globalManager.stats.level
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level \(level.level) · \(level.title)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("+\(viewModel.earnedXP) XP")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.yellow)
            }
            ProgressView(value: level.progress)
                .tint(level.color)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var mistakesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { showMistakes.toggle() }
            } label: {
                HStack {
                    Text("Deine Fehler (\(mistakes.count))")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showMistakes ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showMistakes {
                ForEach(mistakes) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        if let imageName = entry.question.imageName, UIImage(named: imageName) != nil {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(entry.question.prompt(quizId: viewModel.quiz.id))
                            .font(.subheadline.weight(.semibold))
                        Label(entry.chosenAnswer, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Label(entry.correctAnswer, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Text("Fertig")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            Button {
                withAnimation { viewModel.restart() }
            } label: {
                Label("Nochmal", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    func getFeedback(for score: Double) -> String {
        switch score {
        case 100: return "Perfekt! Volle Punktzahl! 🏆"
        case 80..<100: return "Sehr gut! Starke Leistung."
        case 50..<80: return "Solide! Da geht aber noch mehr."
        case 25..<50: return "Ausbaufähig. Lass uns weiterüben!"
        default: return "Kopf hoch! Versuch es noch einmal."
        }
    }
}
// MARK: - Sub-Views

struct StatBox: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)
            
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(color.opacity(0.8))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 15).fill(color.opacity(0.1)))
    }
}
