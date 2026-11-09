//
//  QuizSetupView.swift
//  IOS - Quizzen
//
//  Auswahl von Schwierigkeits-Presets bzw. eigenen Einstellungen
//  (eingebettet in QuizDetailView, funktioniert für jedes Quiz im Katalog).
//

import SwiftUI
import Combine

/// Merkt sich pro Quiz die zuletzt gewählte Stufe und die eigenen Einstellungen
@MainActor
final class QuizSetupModel: ObservableObject {
    let definition: QuizDefinition

    @Published var level: QuizPreset.Level {
        didSet { UserDefaults.standard.set(level.rawValue, forKey: key("preset")) }
    }
    @Published var custom: QuizConfig {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(custom), forKey: key("custom")) }
    }

    init(definition: QuizDefinition) {
        self.definition = definition
        let defaults = UserDefaults.standard
        let prefix = "quizSetup.\(definition.id)."
        level = defaults.string(forKey: prefix + "preset").flatMap(QuizPreset.Level.init) ?? .easy
        let stored = defaults.data(forKey: prefix + "custom")
            .flatMap { try? JSONDecoder().decode(QuizConfig.self, from: $0) }
        let start = stored ?? definition.presets.first(where: { $0.level == .medium })?.config ?? QuizConfig()
        custom = Self.normalized(start, for: definition)
    }

    static let questionCountChoices = [10, 20, 30, 0]
    static let timeLimitChoices: [Int?] = [nil, 20, 10, 5]

    /// Werte auf die im Setup wählbaren Optionen runden (Presets nutzen z. B. 15 Fragen)
    static func normalized(_ config: QuizConfig, for definition: QuizDefinition) -> QuizConfig {
        var config = config
        if !questionCountChoices.contains(config.questionCount) {
            config.questionCount = [10, 20, 30].min { abs($0 - config.questionCount) < abs($1 - config.questionCount) } ?? 10
        }
        if let time = config.timeLimit, !timeLimitChoices.contains(time) {
            config.timeLimit = [20, 10, 5].min { abs($0 - time) < abs($1 - time) }
        }
        if !definition.answerChoices.contains(config.answerCount) {
            config.answerCount = min(4, definition.maxAnswers)
        }
        return config
    }

    private func key(_ name: String) -> String { "quizSetup.\(definition.id).\(name)" }

    var preset: QuizPreset {
        definition.presets.first { $0.level == level } ?? definition.presets[0]
    }

    var activeConfig: QuizConfig { preset.config ?? custom }
}

// MARK: - Setup-Bereich

struct QuizSetupSection: View {
    @ObservedObject var model: QuizSetupModel
    /// Bereits richtig beantwortete Fragen (für „Nur unbekannte“)
    let knownQuestions: Set<String>

    private var definition: QuizDefinition { model.definition }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schwierigkeit")
                .font(.headline)

            ForEach(definition.presets) { preset in
                presetCard(preset)
            }

            if model.level == .custom {
                customPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: model.level)
    }

    // MARK: Preset-Karte

    private func presetCard(_ preset: QuizPreset) -> some View {
        let isSelected = model.level == preset.level
        return Button {
            model.level = preset.level
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: preset.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(preset.color.gradient, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(preset.name).font(.subheadline.weight(.semibold))
                        Text(preset.level.label)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundStyle(preset.color)
                            .background(preset.color.opacity(0.15), in: Capsule())
                    }
                    Text(preset.config.map(definition.summary) ?? preset.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? preset.color : Color(.tertiaryLabel))
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? preset.color : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Eigene Einstellungen

    private var customPanel: some View {
        let available = definition.availableCount(for: model.custom, knownQuestions: knownQuestions)

        return VStack(alignment: .leading, spacing: 18) {
            ForEach(definition.visibleFilters) { filter in
                setting(filter.title) {
                    OptionChips(options: filter.options,
                                isSelected: { model.custom.includes(filter: filter.id, option: $0.id) }) { option in
                        toggle(option: option, in: filter)
                    }
                }
            }

            setting("Fragen pro Runde") {
                Picker("Fragen", selection: $model.custom.questionCount) {
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("30").tag(30)
                    Text("Alle").tag(0)
                }
                .pickerStyle(.segmented)
            }

            setting("Antwortmöglichkeiten") {
                Picker("Antworten", selection: $model.custom.answerCount) {
                    ForEach(definition.answerChoices, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if definition.supportsRandomDistractors {
                setting("Falsche Antworten") {
                    Picker("Falsche Antworten", selection: $model.custom.distractors) {
                        ForEach(QuizConfig.Distractors.allCases, id: \.self) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(model.custom.distractors == .similar
                         ? "Leicht zu verwechselnde Antworten – deutlich schwerer."
                         : "Beliebige andere Antworten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            setting("Zeit pro Frage") {
                Picker("Zeit", selection: $model.custom.timeLimit) {
                    Text("Aus").tag(Int?.none)
                    Text("20 s").tag(Int?.some(20))
                    Text("10 s").tag(Int?.some(10))
                    Text("5 s").tag(Int?.some(5))
                }
                .pickerStyle(.segmented)
            }

            VStack(spacing: 10) {
                if let starterLabel = definition.starterLabel {
                    Toggle(isOn: $model.custom.starterOnly) {
                        Label(starterLabel, systemImage: "star")
                    }
                }
                Toggle(isOn: $model.custom.onlyUnknown) {
                    Label("Nur \(definition.unit.plural), die ich noch nicht kann", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .font(.subheadline)
            .tint(.purple)

            Label(available == 0
                  ? "Keine \(definition.unit.plural) passen zu diesen Einstellungen."
                  : "\(available) \(available == 1 ? definition.unit.singular : definition.unit.plural) verfügbar",
                  systemImage: available == 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(available == 0 ? .red : .secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

    }

    /// Mehrfachauswahl, mindestens eine Option bleibt aktiv
    private func toggle(option: QuizFilterOption, in filter: QuizFilter) {
        var selected = model.custom.selections[filter.id] ?? Set(filter.options.map(\.id))
        if selected.contains(option.id) {
            if selected.count > 1 { selected.remove(option.id) }
        } else {
            selected.insert(option.id)
        }
        model.custom.selections[filter.id] = selected.count == filter.options.count ? nil : selected
    }

    private func setting<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }
}

// MARK: - Mehrfachauswahl als Chips

struct OptionChips: View {
    let options: [QuizFilterOption]
    let isSelected: (QuizFilterOption) -> Bool
    let onTap: (QuizFilterOption) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(options) { option in
                let selected = isSelected(option)
                Button { onTap(option) } label: {
                    Label(option.name, systemImage: option.icon)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(selected ? AnyShapeStyle(Color.purple.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Startet eine generierte Runde

/// Erzeugt die Runde genau einmal beim Öffnen (und bei „Nochmal“ neu).
struct QuizRoundContainer: View {
    @EnvironmentObject var statsManager: StatsManager
    let definition: QuizDefinition
    let config: QuizConfig
    let label: String
    let knownQuestions: Set<String>

    @State private var round: QuizDetail?

    var body: some View {
        Group {
            if let round {
                QuizPlayView(currentQuiz: round, statsManager: statsManager) {
                    definition.build(config: config, label: label, knownQuestions: knownQuestions)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if round == nil {
                round = definition.build(config: config, label: label, knownQuestions: knownQuestions)
            }
        }
    }
}
