//
//  ProfileStatsView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 31.07.26.
//

import SwiftUI

struct ProfileStatsView: View {
    @EnvironmentObject var statsManager: StatsManager

    var body: some View {
        List {
            overviewSection

            ForEach(QuizCatalog.categories) { category in
                Section {
                    ForEach(category.quizzes) { definition in
                        quizStatsRow(definition)
                        breakdownRows(definition)
                    }
                } header: {
                    Label(category.name, systemImage: category.icon)
                }
            }
        }
        .navigationTitle("Statistiken")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Gesamt-Übersicht

    private var overviewSection: some View {
        let stats = statsManager.globalManager.stats

        return Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCell("Aktuelle Streak", "\(stats.currentStreak)", "flame.fill", .orange)
                overviewCell("Beste Streak", "\(stats.bestStreak)", "flame", .orange.opacity(0.7))
                overviewCell("Runden gespielt", "\(stats.quizzesPlayed)", "repeat", .blue)
                overviewCell("Fragen beantwortet", "\(stats.totalAnswers)", "bubble.left.and.bubble.right.fill", .purple)
                overviewCell("Richtige Antworten", "\(stats.correctAnswers)", "checkmark.circle.fill", .green)
                overviewCell("Falsche Antworten", "\(stats.falseAnswers)", "xmark.circle.fill", .red)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Gesamtübersicht")
        }
    }

    private func overviewCell(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title3).bold()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Pro Quiz

    private func quizStatsRow(_ definition: QuizDefinition) -> some View {
        let quiz = definition.baseQuiz
        let stats = statsManager.getStats(for: quiz)
        let total = quiz.questionCount
        let percentFinished = stats.percentFinished(totalQuestions: total)

        return VStack(alignment: .leading, spacing: 8) {
            Label(definition.title, systemImage: definition.icon)
                .font(.headline)
            HStack {
                Text("\(stats.answeredCount) von \(total) \(definition.unit.plural) gesehen")
                    .font(.subheadline)
                Spacer()
                if stats.roundsPlayed > 0 {
                    Text("\(stats.roundsPlayed)× gespielt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if stats.answeredCount > 0 {
                ProgressView(value: Double(percentFinished), total: 100)
                    .tint(progressColor(percentFinished))
                Label("\(stats.percentCorrect) % richtig beantwortet", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("Noch nicht gespielt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// Fortschritt je Option der ersten Aufteilung (z. B. pro Region)
    @ViewBuilder
    private func breakdownRows(_ definition: QuizDefinition) -> some View {
        let stats = statsManager.getStats(for: definition.baseQuiz)
        if stats.answeredCount > 0, let filter = definition.visibleFilters.first {
            ForEach(filter.options) { option in
                let ids = Set(definition.items.filter { $0.tags[filter.id] == option.id }.map(\.question.id))
                let seen = stats.answeredIDs.intersection(ids).count
                let correct = stats.correctIDs.intersection(ids).count
                HStack(spacing: 10) {
                    Image(systemName: option.icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(option.name).font(.caption.weight(.medium))
                            Spacer()
                            Text("\(seen)/\(ids.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            if seen > 0 {
                                Text("· \(Int(Double(correct) / Double(seen) * 100)) % richtig")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ProgressView(value: Double(seen), total: Double(max(ids.count, 1)))
                            .tint(progressColor(ids.isEmpty ? 0 : seen * 100 / ids.count))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func progressColor(_ percent: Int) -> Color {
        switch percent {
        case 100: .green
        case 50...: .blue
        default: .orange
        }
    }
}
