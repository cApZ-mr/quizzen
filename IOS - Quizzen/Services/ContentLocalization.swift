//
//  ContentLocalization.swift
//  IOS - Quizzen
//
//  Übersetzung von Inhalten (Quizfragen, Antworten, Länder, Quiz-Titel).
//
//  Oberflächentexte stehen im String-Katalog (Localizable.xcstrings).
//  Inhalte bleiben intern deutsch – sie dienen als IDs für Fortschritt,
//  Bestenlisten und Duelle – und werden nur für die Anzeige übersetzt.
//  Die Übersetzungen liegen in Content_<sprache>.json (deutsch → Zielsprache).
//

import Foundation

nonisolated enum ContentLocalization {
    /// Sprache, in der die App gerade läuft („de“, „en“ …)
    static let language: String = Bundle.main.preferredLocalizations.first ?? "de"

    static var isGerman: Bool { language.hasPrefix("de") }

    private static let table: [String: String] = {
        guard !isGerman,
              let url = Bundle.main.url(forResource: "Content_\(language)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }()

    /// Übersetzt einen deutschen Inhaltstext. Ohne Übersetzung bleibt er unverändert.
    static func tr(_ text: String) -> String {
        guard !isGerman, !text.isEmpty else { return text }
        return table[text] ?? text
    }

    /// Antwort im Kontext ihrer Frage übersetzen (z. B. „Kongo“ als Fluss statt als Land)
    static func tr(option: String, question: String) -> String {
        guard !isGerman else { return option }
        return table[question + "\u{1F}" + option] ?? tr(option)
    }
}

/// Kurzform für Inhaltstexte
nonisolated func tr(_ text: String) -> String { ContentLocalization.tr(text) }
