//
//  CategoryView.swift
//  IOS - Quizzen
//
//  Ein Themenbereich (z. B. Geografie) mit all seinen Quizzen.
//

import SwiftUI

struct CategoryView: View {
    @EnvironmentObject var statsManager: StatsManager
    let category: QuizCategory

    /// Anteil aller Fragen des Bereichs, die schon gesehen wurden
    private var progress: (seen: Int, total: Int) {
        category.quizzes.reduce((0, 0)) { result, definition in
            let stats = statsManager.getStats(for: definition.baseQuiz)
            return (result.0 + stats.answeredCount, result.1 + definition.items.count)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(spacing: 12) {
                    ForEach(category.quizzes) { definition in
                        let quiz = definition.baseQuiz
                        NavigationLink(value: quiz) {
                            HomeQuizCard(quiz: quiz, stats: statsManager.getStats(for: quiz))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(
            ZStack {
                Color(.systemGroupedBackground)
                LinearGradient(colors: [category.color.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
            }
            .ignoresSafeArea()
        )
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var header: some View {
        let (seen, total) = progress
        let percent = total == 0 ? 0 : Int(Double(seen) / Double(total) * 100)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: category.icon)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(category.color.gradient, in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                    Text("\(category.quizzes.count == 1 ? "1 Quiz" : "\(category.quizzes.count) Quizze") · \(total) Fragen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(category.description)
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Bereich erkundet").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(percent) %").font(.subheadline.weight(.semibold).monospacedDigit())
                }
                ProgressView(value: Double(seen), total: Double(max(total, 1)))
                    .tint(category.color)
                Text("\(seen) von \(total) Fragen gesehen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.top, 8)
    }
}
