//
//  QuizCatalog.swift
//  IOS - Quizzen
//
//  Jedes Thema ist EIN Quiz. Statt fester Einzel-Quizze wählt man eine
//  Schwierigkeit (Preset) oder stellt sich die Runde selbst zusammen.
//  Ein QuizDefinition beschreibt: Fragen-Pool, Filter (z. B. Regionen,
//  Schwierigkeit, Richtung), Presets und welche Antwortarten möglich sind.
//

import Foundation
import SwiftUI

// MARK: - Bausteine

/// Eine Auswahlmöglichkeit eines Filters, z. B. „Europa“ oder „Leicht“
struct QuizFilterOption: Identifiable, Hashable {
    let id: String
    let nameKey: String
    let icon: String
    var name: String { tr(nameKey) }

    init(id: String, name: String, icon: String) {
        self.id = id
        self.nameKey = name
        self.icon = icon
    }
}

/// Ein Filter mit mehreren Optionen, z. B. „Regionen“
struct QuizFilter: Identifiable {
    let id: String
    let titleKey: String
    let options: [QuizFilterOption]
    var title: String { tr(titleKey) }

    init(id: String, title: String, options: [QuizFilterOption]) {
        self.id = id
        self.titleKey = title
        self.options = options
    }
}

/// Eine Frage im Pool + Zuordnung zu Filter-Optionen
struct QuizItem {
    let question: Question
    /// filterId → optionId
    let tags: [String: String]
    /// Art der Antwort (z. B. „country“). Nur gleichartige Antworten dürfen als
    /// zufällige Falschantworten dienen. nil = nur handverlesene Antworten.
    let answerType: String?
    /// Gehört zu den „bekannten“ Fragen (Einsteiger-Teilmenge)
    let isStarter: Bool

    var answer: String { question.options[question.correctAnswerIndex] }
    var curatedDistractors: [String] { question.options.filter { $0 != answer } }
}

/// Einstellungen einer Runde
struct QuizConfig: Codable, Equatable {
    enum Distractors: String, Codable, CaseIterable {
        case random, similar
        var name: String { self == .random ? String(localized: "Zufällig") : String(localized: "Ähnlich") }
    }

    /// filterId → gewählte Options-IDs. Fehlt ein Filter, gilt „alle“.
    var selections: [String: Set<String>] = [:]
    var starterOnly = false
    /// 0 = alle verfügbaren Fragen
    var questionCount = 10
    var answerCount = 4
    var distractors: Distractors = .similar
    var timeLimit: Int? = nil
    var onlyUnknown = false

    func includes(filter: String, option: String) -> Bool {
        guard let selected = selections[filter] else { return true }
        return selected.contains(option)
    }
}

/// Schwierigkeits-Stufe eines Quiz. `config == nil` = eigene Einstellungen.
struct QuizPreset: Identifiable {
    enum Level: String, CaseIterable, Codable {
        case easy, medium, hard, extreme, custom

        var label: String {
            switch self {
            case .easy: String(localized: "Leicht")
            case .medium: String(localized: "Mittel")
            case .hard: String(localized: "Schwer")
            case .extreme: String(localized: "Extrem")
            case .custom: String(localized: "Individuell")
            }
        }

        var color: Color {
            switch self {
            case .easy: .green
            case .medium: .blue
            case .hard: .orange
            case .extreme: .red
            case .custom: .purple
            }
        }
    }

    let level: Level
    let nameKey: String
    let icon: String
    let taglineKey: String
    let config: QuizConfig?

    var name: String { tr(nameKey) }
    var tagline: String { tr(taglineKey) }
    var id: String { level.rawValue }

    init(level: Level, name: String, icon: String, tagline: String, config: QuizConfig?) {
        self.level = level
        self.nameKey = name
        self.icon = icon
        self.taglineKey = tagline
        self.config = config
    }
    var color: Color { level.color }

    static func custom(_ tagline: String = "Stell dir deine Runde selbst zusammen") -> QuizPreset {
        QuizPreset(level: .custom, name: "Eigene", icon: "slider.horizontal.3", tagline: tagline, config: nil)
    }
}

// MARK: - Themenbereich

/// Oberkategorie, die mehrere eigenständige Quizze bündelt (z. B. Geografie)
struct QuizCategory: Identifiable, Hashable {
    let id: String
    let nameKey: String
    let icon: String
    let color: Color
    let descriptionKey: String
    let quizzes: [QuizDefinition]

    var name: String { tr(nameKey) }
    var description: String { tr(descriptionKey) }

    init(id: String, name: String, icon: String, color: Color, description: String, quizzes: [QuizDefinition]) {
        self.id = id
        self.nameKey = name
        self.icon = icon
        self.color = color
        self.descriptionKey = description
        self.quizzes = quizzes
    }

    static func == (lhs: QuizCategory, rhs: QuizCategory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var totalQuestions: Int { quizzes.reduce(0) { $0 + $1.items.count } }
}

// MARK: - Quiz-Definition

struct QuizDefinition: Identifiable {
    let id: String
    /// Deutscher Titel – Teil des Statistik-Schlüssels, daher nie übersetzen
    let titleKey: String
    private let descriptionKey: String
    let icon: String
    private let unitKey: (singular: String, plural: String)
    let filters: [QuizFilter]
    private let starterLabelKey: String?
    let presets: [QuizPreset]
    /// Alte Einzel-Quizze, deren Fortschritt/Bestenliste übernommen wird
    let legacyQuizIds: [String]
    /// Für Statistik-Schlüssel (bleibt mit alten Ständen kompatibel)
    let categoryId: String
    let items: [QuizItem]

    init(id: String, title: String, description: String, icon: String, unit: (singular: String, plural: String),
         filters: [QuizFilter], starterLabel: String?, presets: [QuizPreset], legacyQuizIds: [String],
         categoryId: String, items: [QuizItem]) {
        self.id = id
        self.titleKey = title
        self.descriptionKey = description
        self.icon = icon
        self.unitKey = unit
        self.filters = filters
        self.starterLabelKey = starterLabel
        self.presets = presets
        self.legacyQuizIds = legacyQuizIds
        self.categoryId = categoryId
        self.items = items
    }

    /// Angezeigte (ggf. übersetzte) Texte
    var title: String { tr(titleKey) }
    var description: String { tr(descriptionKey) }
    /// z. B. („Flagge“, „Flaggen“) für Texte wie „63 von 197 Flaggen“
    var unit: (singular: String, plural: String) { (tr(unitKey.singular), tr(unitKey.plural)) }
    /// Beschriftung des Einsteiger-Schalters (nil = gibt es nicht)
    var starterLabel: String? { starterLabelKey.map { tr($0) } }

    /// Zufällige Falschantworten nur, wenn alle Antworten typisiert sind
    var supportsRandomDistractors: Bool { items.allSatisfy { $0.answerType != nil } }
    var answerChoices: [Int] { supportsRandomDistractors ? [2, 4, 6] : [2, 3, 4] }
    var maxAnswers: Int { answerChoices.max() ?? 4 }
    /// Filter, die im Setup auftauchen (mit nur einer Option sinnlos)
    var visibleFilters: [QuizFilter] { filters.filter { $0.options.count > 1 } }

    /// Das Quiz, wie es in Listen, Suche und Duell erscheint (ganzer Pool)
    var baseQuiz: QuizDetail {
        QuizDetail(id: id, categoryId: categoryId, subCategory: titleKey, title: title,
                   description: description, imageName: "", difficulty: .medium,
                   questions: items.map(\.question))
    }

    /// Fragen, die eine Einstellung zulässt
    func pool(for config: QuizConfig, knownQuestions: Set<String> = []) -> [QuizItem] {
        items.filter { item in
            filters.allSatisfy { filter in
                guard let tag = item.tags[filter.id] else { return true }
                return config.includes(filter: filter.id, option: tag)
            }
            && (!config.starterOnly || item.isStarter)
            && (!config.onlyUnknown || !knownQuestions.contains(item.question.id))
        }
    }

    func availableCount(for config: QuizConfig, knownQuestions: Set<String> = []) -> Int {
        pool(for: config, knownQuestions: knownQuestions).count
    }

    /// Kurzbeschreibung einer Einstellung, z. B. „Europa · 10 Fragen · 4 Antworten · 15 s“
    func summary(of config: QuizConfig) -> String {
        var parts: [String] = []
        for filter in visibleFilters {
            guard let selected = config.selections[filter.id], selected.count < filter.options.count else { continue }
            parts.append(filter.options.filter { selected.contains($0.id) }.map(\.name).joined(separator: ", "))
        }
        if config.starterOnly, let starterLabelKey { parts.append(tr(starterLabelKey.replacingOccurrences(of: "Nur ", with: ""))) }
        if parts.isEmpty { parts.append(String(localized: "Alles gemischt")) }
        parts.append(config.questionCount == 0 ? String(localized: "alle \(availableCount(for: config))")
                                               : String(localized: "\(config.questionCount) Fragen"))
        parts.append(String(localized: "\(config.answerCount) Antworten"))
        if let time = config.timeLimit { parts.append("\(time) s") }
        return parts.joined(separator: " · ")
    }

    // MARK: Runde erzeugen

    func build(config: QuizConfig, label: String, knownQuestions: Set<String> = [],
               using rng: inout some RandomNumberGenerator) -> QuizDetail {
        let candidates = pool(for: config, knownQuestions: knownQuestions).shuffled(using: &rng)
        let count = config.questionCount == 0 ? candidates.count : min(config.questionCount, candidates.count)
        let answerCount = max(2, min(config.answerCount, maxAnswers))

        let questions: [Question] = candidates.prefix(count).map { item in
            makeQuestion(for: item, answerCount: answerCount, distractors: config.distractors, using: &rng)
        }

        var quiz = baseQuiz
        quiz = QuizDetail(id: quiz.id, categoryId: quiz.categoryId, subCategory: quiz.subCategory,
                          title: quiz.title, description: quiz.description, imageName: quiz.imageName,
                          difficulty: quiz.difficulty, questions: questions,
                          settings: QuizPlaySettings(roundLength: questions.count, timeLimit: config.timeLimit, label: label))
        return quiz
    }

    /// Baut die Antwortmöglichkeiten einer Frage. „Ähnlich“ nimmt zuerst die
    /// handverlesenen Falschantworten, dann gleichartige Antworten derselben
    /// Gruppe (z. B. Region), zuletzt beliebige gleichartige Antworten.
    func makeQuestion(for item: QuizItem, answerCount requested: Int, distractors style: QuizConfig.Distractors,
                      using rng: inout some RandomNumberGenerator) -> Question {
        let answerCount = max(2, min(requested, maxAnswers))
        let correct = item.answer
        let primaryFilter = filters.first?.id
        var distractors: [String] = []
        func add(_ names: [String]) {
            for name in names {
                guard distractors.count < answerCount - 1 else { return }
                if name != correct && !distractors.contains(name) { distractors.append(name) }
            }
        }
        let sameType = items.filter { $0.answerType != nil && $0.answerType == item.answerType && $0.answer != correct }

        if style == .similar || item.answerType == nil {
            add(item.curatedDistractors.shuffled(using: &rng))
            if let primaryFilter {
                add(sameType.filter { $0.tags[primaryFilter] == item.tags[primaryFilter] }
                    .map(\.answer).shuffled(using: &rng))
            }
        }
        add(sameType.map(\.answer).shuffled(using: &rng))
        add(item.curatedDistractors)   // Fallback

        var options = distractors + [correct]
        options.shuffle(using: &rng)
        return Question(question: item.question.question, imageName: item.question.imageName,
                        options: options, correctAnswerIndex: options.firstIndex(of: correct) ?? 0,
                        promptText: item.question.imageName == nil ? nil : item.question.prompt(quizId: id),
                        key: item.question.key)
    }

    func build(config: QuizConfig, label: String, knownQuestions: Set<String> = []) -> QuizDetail {
        var rng = SystemRandomNumberGenerator()
        return build(config: config, label: label, knownQuestions: knownQuestions, using: &rng)
    }
}

// MARK: - Katalog

enum QuizCatalog {

    /// Themenbereiche (Reihenfolge = Anzeige-Reihenfolge). Ein neues Quiz wird
    /// unten definiert und hier seinem Bereich zugeordnet.
    static let categories: [QuizCategory] = [
        QuizCategory(id: "geography", name: "Geografie", icon: "globe.europe.africa.fill", color: .teal,
                     description: "Länder, Flaggen, Städte und Flughäfen der Welt.",
                     quizzes: [flags, capitals, airportCodes]),
        QuizCategory(id: "knowledge", name: "Wissen", icon: "brain.head.profile.fill", color: .orange,
                     description: "Allgemeinbildung, Geschichte und Naturwissenschaften.",
                     quizzes: [basics, history, science]),
        QuizCategory(id: "entertainment", name: "Film & Musik", icon: "film.fill", color: .purple,
                     description: "Kino, Serien und die Welten, die wir lieben.",
                     quizzes: [movies, harryPotter]),
        QuizCategory(id: "sport", name: "Sport", icon: "sportscourt.fill", color: .green,
                     description: "Regeln, Rekorde und Legenden aus der Welt des Sports.",
                     quizzes: [sports]),
    ]

    /// Alle Quizze in Anzeige-Reihenfolge (nach Themenbereichen)
    static let all: [QuizDefinition] = categories.flatMap(\.quizzes)

    static func definition(for quizId: String) -> QuizDefinition? {
        all.first { $0.id == quizId }
    }

    static func category(for quizId: String) -> QuizCategory? {
        categories.first { $0.quizzes.contains { $0.id == quizId } }
    }

    // MARK: Gemeinsame Filter

    static let regionFilter = QuizFilter(id: "region", title: "Regionen", options: [
        .init(id: "europe", name: "Europa", icon: "globe.europe.africa.fill"),
        .init(id: "africa", name: "Afrika", icon: "globe.europe.africa.fill"),
        .init(id: "america", name: "Amerika", icon: "globe.americas.fill"),
        .init(id: "asia", name: "Asien", icon: "globe.asia.australia.fill"),
        .init(id: "oceania", name: "Ozeanien", icon: "globe.asia.australia.fill"),
    ])

    private static let regionFiles: [(id: String, suffix: String)] = [
        ("europe", "Europe"), ("africa", "Africa"), ("america", "America"), ("asia", "Asia"), ("oceania", "Oceania")
    ]

    private static func only(_ filter: String, _ options: String...) -> [String: Set<String>] {
        [filter: Set(options)]
    }

    // MARK: Allgemeinwissen

    static let basics: QuizDefinition = {
        let levels: [(id: String, file: String)] = [("easy", "BasicsEasy"), ("medium", "BasicsMiddle"), ("hard", "BasicsHard")]
        let items = levels.flatMap { level in
            (DataService.loadQuiz(from: level.file)?.questions ?? []).map {
                QuizItem(question: $0, tags: ["level": level.id], answerType: nil, isStarter: level.id == "easy")
            }
        }
        return QuizDefinition(
            id: "Basics", title: "Allgemeinwissen",
            description: "Wissen aus allen Bereichen – von Alltagsfragen bis zu Wissenschaft und Philosophie.",
            icon: "brain.head.profile.fill", unit: ("Frage", "Fragen"),
            filters: [QuizFilter(id: "level", title: "Schwierigkeit", options: [
                .init(id: "easy", name: "Leicht", icon: "leaf.fill"),
                .init(id: "medium", name: "Mittel", icon: "flame.fill"),
                .init(id: "hard", name: "Schwer", icon: "bolt.fill"),
            ])],
            starterLabel: nil,
            presets: [
                QuizPreset(level: .easy, name: "Einsteiger", icon: "lightbulb.fill", tagline: "",
                           config: QuizConfig(selections: only("level", "easy"), questionCount: 10, answerCount: 4)),
                QuizPreset(level: .medium, name: "Fortgeschritten", icon: "book.fill", tagline: "",
                           config: QuizConfig(selections: only("level", "easy", "medium"), questionCount: 15, answerCount: 4)),
                QuizPreset(level: .hard, name: "Experte", icon: "graduationcap.fill", tagline: "",
                           config: QuizConfig(selections: only("level", "medium", "hard"), questionCount: 15, answerCount: 4, timeLimit: 20)),
                QuizPreset(level: .extreme, name: "Genie", icon: "brain.fill", tagline: "",
                           config: QuizConfig(questionCount: 30, answerCount: 4, timeLimit: 10)),
                .custom(),
            ],
            legacyQuizIds: ["BasicsEasy", "BasicsMiddle", "BasicsHard"],
            categoryId: "basics",
            items: items)
    }()

    // MARK: Flaggen

    /// Bekannte Flaggen für Einsteiger (ISO-Codes = Asset-Namen)
    static let wellKnownFlags: Set<String> = [
        "de", "fr", "it", "es", "gb", "us", "ca", "mx", "br", "ar", "jp", "cn", "in", "kr", "au",
        "ru", "tr", "ch", "at", "nl", "be", "se", "no", "dk", "fi", "pl", "pt", "gr", "ie", "za",
        "eg", "ng", "ke", "ma", "sa", "il", "th", "vn", "nz", "co", "cl", "ua", "cz", "hr", "jm",
        "cu", "pe", "ph", "id", "is"
    ]

    static let flags: QuizDefinition = {
        let items = regionFiles.flatMap { region in
            (DataService.loadQuiz(from: "Flags\(region.suffix)")?.questions ?? []).map {
                QuizItem(question: $0, tags: ["region": region.id], answerType: "country",
                         isStarter: wellKnownFlags.contains($0.imageName ?? ""))
            }
        }
        return QuizDefinition(
            id: "Flags", title: "Flaggen",
            description: "Erkenne die Flaggen der Welt – von den bekanntesten bis zu allen 197.",
            icon: "flag.fill", unit: ("Flagge", "Flaggen"),
            filters: [regionFilter],
            starterLabel: "Nur bekannte Flaggen",
            presets: [
                QuizPreset(level: .easy, name: "Entdecker", icon: "binoculars.fill", tagline: "",
                           config: QuizConfig(starterOnly: true, questionCount: 10, answerCount: 4, distractors: .random)),
                QuizPreset(level: .medium, name: "Weltreisender", icon: "airplane", tagline: "",
                           config: QuizConfig(questionCount: 15, answerCount: 4, distractors: .similar)),
                QuizPreset(level: .hard, name: "Kenner", icon: "graduationcap.fill", tagline: "",
                           config: QuizConfig(questionCount: 20, answerCount: 6, distractors: .similar, timeLimit: 15)),
                QuizPreset(level: .extreme, name: "Weltmeister", icon: "crown.fill", tagline: "",
                           config: QuizConfig(questionCount: 0, answerCount: 6, distractors: .similar, timeLimit: 8)),
                .custom(),
            ],
            legacyQuizIds: ["FlagsEurope", "FlagsAfrica", "FlagsAmerica", "FlagsAsia", "FlagsOceania", "FlagsWorld"],
            categoryId: "flags",
            items: items)
    }()

    // MARK: Hauptstädte

    static let capitals: QuizDefinition = {
        let items = regionFiles.flatMap { region in
            (DataService.loadQuiz(from: "Capitals\(region.suffix)")?.questions ?? []).map { question -> QuizItem in
                let toCapital = question.id.hasPrefix("Was ist die Hauptstadt")
                return QuizItem(question: question,
                                tags: ["region": region.id, "direction": toCapital ? "toCapital" : "toCountry"],
                                answerType: toCapital ? "capital" : "country",
                                isStarter: region.id == "europe")
            }
        }
        let direction = QuizFilter(id: "direction", title: "Fragerichtung", options: [
            .init(id: "toCapital", name: "Land → Hauptstadt", icon: "building.columns.fill"),
            .init(id: "toCountry", name: "Hauptstadt → Land", icon: "map.fill"),
        ])
        return QuizDefinition(
            id: "Capitals", title: "Hauptstädte",
            description: "Kennst du die Hauptstädte der Welt? Und umgekehrt: Zu welchem Land gehört die Stadt?",
            icon: "building.columns.fill", unit: ("Frage", "Fragen"),
            filters: [regionFilter, direction],
            starterLabel: nil,
            presets: [
                QuizPreset(level: .easy, name: "Entdecker", icon: "binoculars.fill", tagline: "",
                           config: QuizConfig(selections: ["region": ["europe"], "direction": ["toCapital"]],
                                              questionCount: 10, answerCount: 4, distractors: .random)),
                QuizPreset(level: .medium, name: "Weltreisender", icon: "airplane", tagline: "",
                           config: QuizConfig(selections: only("direction", "toCapital"), questionCount: 15, answerCount: 4)),
                QuizPreset(level: .hard, name: "Kenner", icon: "graduationcap.fill", tagline: "",
                           config: QuizConfig(questionCount: 20, answerCount: 6, timeLimit: 15)),
                QuizPreset(level: .extreme, name: "Weltmeister", icon: "crown.fill", tagline: "",
                           config: QuizConfig(selections: only("direction", "toCapital"), questionCount: 0, answerCount: 6, timeLimit: 8)),
                .custom(),
            ],
            legacyQuizIds: ["CapitalsEurope", "CapitalsAfrica", "CapitalsAmerica", "CapitalsAsia", "CapitalsOceania", "CapitalsWorld"],
            categoryId: "geography",
            items: items)
    }()

    // MARK: Flughafen-Codes

    static let airportCodes: QuizDefinition = {
        let items = (DataService.loadQuiz(from: "AviationAirportCodes")?.questions ?? []).map { question -> QuizItem in
            let toCode = question.id.hasPrefix("Abkürzung")
            return QuizItem(question: question, tags: ["direction": toCode ? "toCode" : "toAirport"],
                            answerType: toCode ? "code" : "airport", isStarter: false)
        }
        return QuizDefinition(
            id: "Aviation", title: "Flughafen-Codes",
            description: "FRA, JFK, HKG – erkennst du die Flughäfen der Welt an ihren drei Buchstaben?",
            icon: "airplane.departure", unit: ("Frage", "Fragen"),
            filters: [QuizFilter(id: "direction", title: "Fragerichtung", options: [
                .init(id: "toCode", name: "Flughafen → Code", icon: "textformat.abc"),
                .init(id: "toAirport", name: "Code → Flughafen", icon: "airplane"),
            ])],
            starterLabel: nil,
            presets: [
                QuizPreset(level: .easy, name: "Abflug", icon: "airplane.departure", tagline: "",
                           config: QuizConfig(selections: only("direction", "toCode"), questionCount: 10, answerCount: 4, distractors: .random)),
                QuizPreset(level: .medium, name: "Reiseflug", icon: "cloud.fill", tagline: "",
                           config: QuizConfig(questionCount: 15, answerCount: 4)),
                QuizPreset(level: .hard, name: "Langstrecke", icon: "globe", tagline: "",
                           config: QuizConfig(questionCount: 20, answerCount: 6, timeLimit: 15)),
                QuizPreset(level: .extreme, name: "Kapitän", icon: "star.circle.fill", tagline: "",
                           config: QuizConfig(questionCount: 0, answerCount: 6, timeLimit: 8)),
                .custom(),
            ],
            legacyQuizIds: ["AviationAirportCodes"],
            categoryId: "aviation",
            items: items)
    }()

    // MARK: Harry Potter

    static let harryPotter: QuizDefinition = {
        let items = (DataService.loadQuiz(from: "FilmsHarryPotter")?.questions ?? []).map {
            QuizItem(question: $0, tags: [:], answerType: nil, isStarter: false)
        }
        return QuizDefinition(
            id: "HarryPotter", title: "Harry Potter",
            description: "Hogwarts, Horkruxe und Quidditch – wie gut kennst du die Zaubererwelt?",
            icon: "wand.and.stars", unit: ("Frage", "Fragen"),
            filters: [],
            starterLabel: nil,
            presets: standardPresets(names: ["Muggel", "Zauberlehrling", "Auror", "Zaubereiminister"],
                                     icons: ["person.fill", "book.closed.fill", "wand.and.rays", "crown.fill"]),
            legacyQuizIds: ["FilmsHarryPotter"],
            categoryId: "harrypotter",
            items: items)
    }()

    // MARK: Themen-Quizze (Geschichte, Wissenschaft, Sport, Film & Serien)

    /// Gleiche Stufen-Logik für Quizze ohne eigene Schwierigkeitsdaten:
    /// mehr Fragen, mehr Antworten und weniger Zeit je Stufe.
    static func standardPresets(names: [String], icons: [String]) -> [QuizPreset] {
        [
            QuizPreset(level: .easy, name: names[0], icon: icons[0], tagline: "",
                       config: QuizConfig(questionCount: 10, answerCount: 3)),
            QuizPreset(level: .medium, name: names[1], icon: icons[1], tagline: "",
                       config: QuizConfig(questionCount: 15, answerCount: 4)),
            QuizPreset(level: .hard, name: names[2], icon: icons[2], tagline: "",
                       config: QuizConfig(questionCount: 20, answerCount: 4, timeLimit: 15)),
            QuizPreset(level: .extreme, name: names[3], icon: icons[3], tagline: "",
                       config: QuizConfig(questionCount: 0, answerCount: 4, timeLimit: 8)),
            .custom(),
        ]
    }

    /// Quiz aus mehreren Themen-Dateien, Filter „Themen“
    private static func topicQuiz(id: String, title: String, description: String, icon: String,
                                  topics: [(id: String, file: String, name: String, icon: String)],
                                  presetNames: [String], presetIcons: [String]) -> QuizDefinition {
        let items = topics.flatMap { topic in
            (DataService.loadQuiz(from: topic.file)?.questions ?? []).map {
                QuizItem(question: $0, tags: ["topic": topic.id], answerType: nil, isStarter: false)
            }
        }
        return QuizDefinition(
            id: id, title: title, description: description, icon: icon, unit: ("Frage", "Fragen"),
            filters: [QuizFilter(id: "topic", title: "Themen",
                                 options: topics.map { .init(id: $0.id, name: $0.name, icon: $0.icon) })],
            starterLabel: nil,
            presets: standardPresets(names: presetNames, icons: presetIcons),
            legacyQuizIds: [],
            categoryId: id.lowercased(),
            items: items)
    }

    static let history = topicQuiz(
        id: "History", title: "Geschichte",
        description: "Von den Pharaonen bis zum Mauerfall – Ereignisse und Persönlichkeiten aus 5000 Jahren.",
        icon: "building.columns.fill",
        topics: [("antiquity", "HistoryAntiquity", "Antike", "building.columns"),
                 ("middleages", "HistoryMiddleAges", "Mittelalter", "shield.fill"),
                 ("earlymodern", "HistoryEarlyModern", "Neuzeit", "sailboat.fill"),
                 ("modern", "HistoryModern", "20. Jahrhundert", "globe.europe.africa.fill")],
        presetNames: ["Schüler", "Historiker", "Archäologe", "Chronist"],
        presetIcons: ["backpack.fill", "book.fill", "magnifyingglass", "scroll.fill"])

    static let science = topicQuiz(
        id: "Science", title: "Wissenschaft",
        description: "Biologie, Chemie, Physik und Astronomie – wie viel weißt du über die Welt um dich herum?",
        icon: "atom",
        topics: [("biology", "ScienceBiology", "Biologie", "leaf.fill"),
                 ("chemistry", "ScienceChemistry", "Chemie", "flask.fill"),
                 ("physics", "SciencePhysics", "Physik", "bolt.fill"),
                 ("astronomy", "ScienceAstronomy", "Astronomie", "moon.stars.fill")],
        presetNames: ["Neugierig", "Forscher", "Professor", "Nobelpreis"],
        presetIcons: ["questionmark.circle.fill", "testtube.2", "graduationcap.fill", "medal.fill"])

    static let sports = topicQuiz(
        id: "Sports", title: "Sport",
        description: "Fußball, Olympia und vieles mehr – Regeln, Rekorde und Legenden.",
        icon: "sportscourt.fill",
        topics: [("soccer", "SportsSoccer", "Fußball", "soccerball"),
                 ("olympics", "SportsOlympics", "Olympia", "medal.fill"),
                 ("other", "SportsOther", "Weitere Sportarten", "figure.run")],
        presetNames: ["Zuschauer", "Amateur", "Profi", "Legende"],
        presetIcons: ["eyes", "figure.walk", "figure.run", "trophy.fill"])

    static let movies = topicQuiz(
        id: "Movies", title: "Film & Serien",
        description: "Blockbuster, Kultserien und Animationsklassiker – teste dein Wissen über Film und Fernsehen.",
        icon: "film.fill",
        topics: [("films", "MoviesFilms", "Filme", "film.fill"),
                 ("series", "MoviesSeries", "Serien", "tv.fill"),
                 ("animation", "MoviesAnimation", "Animation", "sparkles")],
        presetNames: ["Zuschauer", "Cineast", "Kritiker", "Filmlexikon"],
        presetIcons: ["popcorn.fill", "ticket.fill", "star.fill", "books.vertical.fill"])
}
