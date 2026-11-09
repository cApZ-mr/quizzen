//
//  QuizDetailView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 29.05.26.
//

import Foundation
import SwiftUI

struct QuizDetailView: View {
    @EnvironmentObject var statsManager: StatsManager
    let quiz: QuizDetail

    /// Gewählte Schwierigkeit / eigene Einstellungen dieses Quiz
    @StateObject private var setup: QuizSetupModel
    private let definition: QuizDefinition?

    init(quiz: QuizDetail) {
        self.quiz = quiz
        let definition = quiz.definition
        self.definition = definition
        _setup = StateObject(wrappedValue: QuizSetupModel(definition: definition ?? QuizCatalog.all[0]))
    }

    private var knownQuestions: Set<String> { stats.correctIDs }
    private var canStart: Bool {
        guard let definition else { return true }
        return definition.availableCount(for: setup.activeConfig, knownQuestions: knownQuestions) > 0
    }

    private var stats: CategoryStats { statsManager.getStats(for: quiz) }
    private var questionsPerRound: Int { min(quiz.questionCount, 15) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                QuizCoverView(quiz: quiz)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 8)

                header
                if definition != nil {
                    progressCard
                    QuizSetupSection(model: setup, knownQuestions: knownQuestions)
                } else {
                    infoPills
                    progressCard
                    howItWorks
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(backgroundGlow)
        .safeAreaInset(edge: .bottom) { playButton }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Teile

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let definition {
                HStack(spacing: 6) {
                    if let category = QuizCatalog.category(for: quiz.id) {
                        Text(category.name.uppercased())
                            .tracking(1.2)
                            .foregroundStyle(category.color)
                        Text("·")
                    }
                    Text("\(quiz.questionCount) \(definition.unit.plural) · \(definition.presets.count) Stufen")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            Text(quiz.title)
                .font(.system(.largeTitle, design: .rounded).weight(.black))
                .fixedSize(horizontal: false, vertical: true)
            Text(quiz.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
    }

    private var infoPills: some View {
        HStack(spacing: 10) {
            DifficultyBadge(difficulty: quiz.difficulty)
            pill("\(quiz.questionCount) Fragen", "square.stack.3d.up.fill")
            pill("\(questionsPerRound) pro Runde", "timer")
        }
    }

    private var progressCard: some View {
        let percentFinished = stats.percentFinished(totalQuestions: quiz.questionCount)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Dein Fortschritt")
                .font(.headline)

            if stats.answeredCount == 0 {
                Label("Du hast dieses Quiz noch nicht gespielt. Leg los!", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView(value: Double(percentFinished), total: 100)
                    .tint(percentFinished == 100 ? .green : .brandLight)

                HStack(spacing: 0) {
                    progressStat("\(stats.answeredCount)/\(quiz.questionCount)", "\(definition?.unit.plural ?? "Fragen") gesehen")
                    progressStat("\(stats.percentCorrect) %", "richtig")
                    progressStat("\(stats.roundsPlayed)", stats.roundsPlayed == 1 ? "Runde" : "Runden")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("So funktioniert's")
                .font(.headline)
            ruleRow("shuffle", "Jede Runde zieht \(questionsPerRound) zufällige Fragen.")
            ruleRow("hand.tap.fill", "Antwort wählen, dann bestätigen – erst danach siehst du die Lösung.")
            ruleRow("chart.line.uptrend.xyaxis", "Richtige Antworten zählen für deine Statistik und die Bestenliste.")
        }
    }

    private var playButton: some View {
        NavigationLink {
            if let definition {
                QuizRoundContainer(definition: definition, config: setup.activeConfig,
                                   label: setup.preset.name, knownQuestions: knownQuestions)
            } else {
                QuizPlayView(currentQuiz: quiz, statsManager: statsManager)
            }
        } label: {
            Label(playTitle, systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(definition != nil ? AnyShapeStyle(setup.preset.color.gradient) : AnyShapeStyle(Color.brand),
                            in: RoundedRectangle(cornerRadius: 18))
                .opacity(canStart ? 1 : 0.4)
        }
        .disabled(!canStart)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private var playTitle: String {
        if definition != nil { return "\(setup.preset.name) starten" }
        return stats.roundsPlayed > 0 ? "Nochmal spielen" : "Quiz starten"
    }

    private var backgroundGlow: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(colors: QuizCoverTheme.forQuiz(quiz).colors.map { $0.opacity(0.35) } + [.clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }

    // MARK: - Helfer

    private func pill(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func progressStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func ruleRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandLight)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
