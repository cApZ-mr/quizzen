//
//  PvPDuelSettingsView.swift
//  IOS - Quizzen
//
//  Einstellungen des Hosts für ein Duell: Stufe des Quiz oder eigene
//  Einstellungen (Fragen, Zeit, Antworten, Filter).
//

import SwiftUI

/// Gewählte Duell-Einstellungen (vom Host im Warteraum)
struct DuelSetup: Equatable {
    var level: QuizPreset.Level = .medium
    var custom = QuizConfig(questionCount: 10, answerCount: 4, distractors: .similar)
    var customDuration = 20

    static let questionCounts = [5, 10, 15, 20]
    static let durations = [10, 15, 20, 30]

    /// Effektive Einstellungen fürs Duell. Presets werden begrenzt:
    /// höchstens 20 Fragen, immer mit Zeitlimit (Standard 20 s).
    func resolved(for definition: QuizDefinition) -> (config: QuizConfig, duration: Int, label: String) {
        var config: QuizConfig
        var duration: Int
        let label: String

        if level != .custom, let preset = definition.presets.first(where: { $0.level == level }), let presetConfig = preset.config {
            config = presetConfig
            config.questionCount = (presetConfig.questionCount == 0 || presetConfig.questionCount > 20) ? 20 : presetConfig.questionCount
            duration = presetConfig.timeLimit.map { min(max($0, 5), 30) } ?? 20
            label = preset.name
        } else {
            config = custom
            duration = customDuration
            label = String(localized: "Eigene")
        }
        config.onlyUnknown = false   // im Duell für beide gleich
        config.answerCount = min(max(config.answerCount, 2), definition.maxAnswers)
        return (config, duration, label)
    }

    /// Beim Quizwechsel: Filter zurücksetzen (jedes Quiz hat andere)
    mutating func adapt(to definition: QuizDefinition) {
        custom.selections = [:]
        custom.starterOnly = false
        if !definition.answerChoices.contains(custom.answerCount) {
            custom.answerCount = min(4, definition.maxAnswers)
        }
    }
}

struct PvPDuelSettingsPanel: View {
    let definition: QuizDefinition
    @Binding var setup: DuelSetup

    private var resolved: (config: QuizConfig, duration: Int, label: String) { setup.resolved(for: definition) }
    private var available: Int { definition.availableCount(for: resolved.config) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Einstellungen").font(.title3.bold())

            // Umbrechendes Raster statt Scroll-Leiste: alle Stufen sichtbar, nichts springt
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(definition.presets) { preset in
                    levelChip(preset)
                }
            }

            summary

            if setup.level == .custom {
                customOptions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: setup.level)
    }

    private func levelChip(_ preset: QuizPreset) -> some View {
        let isActive = setup.level == preset.level
        return Button {
            setup.level = preset.level
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Label(preset.name, systemImage: preset.icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isActive ? .white : .primary)
                .background(isActive ? AnyShapeStyle(preset.color.gradient) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                            in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// „10 Fragen · 4 Antworten · 20 s · Europa“
    private var summary: some View {
        let config = resolved.config
        let count = min(config.questionCount, available)
        var parts = [String(localized: "\(count) Fragen"), String(localized: "\(config.answerCount) Antworten"), String(localized: "\(resolved.duration) s pro Frage")]
        for filter in definition.visibleFilters {
            if let selected = config.selections[filter.id], selected.count < filter.options.count {
                parts.append(filter.options.filter { selected.contains($0.id) }.map(\.name).joined(separator: ", "))
            }
        }
        return Label(parts.joined(separator: " · "), systemImage: available == 0 ? "exclamationmark.triangle.fill" : "slider.horizontal.3")
            .font(.footnote.weight(.medium))
            .foregroundStyle(available == 0 ? .red : .secondary)
    }

    private var customOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(definition.visibleFilters) { filter in
                option(filter.title) {
                    OptionChips(options: filter.options,
                                isSelected: { setup.custom.includes(filter: filter.id, option: $0.id) }) { choice in
                        var selected = setup.custom.selections[filter.id] ?? Set(filter.options.map(\.id))
                        if selected.contains(choice.id) {
                            if selected.count > 1 { selected.remove(choice.id) }
                        } else {
                            selected.insert(choice.id)
                        }
                        setup.custom.selections[filter.id] = selected.count == filter.options.count ? nil : selected
                    }
                }
            }

            option(String(localized: "Fragen")) {
                Picker("Fragen", selection: $setup.custom.questionCount) {
                    ForEach(DuelSetup.questionCounts, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            option(String(localized: "Zeit pro Frage")) {
                Picker("Zeit", selection: $setup.customDuration) {
                    ForEach(DuelSetup.durations, id: \.self) { Text("\($0) s").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            option(String(localized: "Antwortmöglichkeiten")) {
                Picker("Antworten", selection: $setup.custom.answerCount) {
                    ForEach(definition.answerChoices, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if definition.supportsRandomDistractors {
                option(String(localized: "Falsche Antworten")) {
                    Picker("Falsche Antworten", selection: $setup.custom.distractors) {
                        ForEach(QuizConfig.Distractors.allCases, id: \.self) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if let starterLabel = definition.starterLabel {
                Toggle(isOn: $setup.custom.starterOnly) {
                    Label(starterLabel, systemImage: "star")
                }
                .font(.subheadline)
                .tint(.purple)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func option<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }
}
