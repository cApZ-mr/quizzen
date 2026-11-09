//
//  BadgeModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.07.26.
//

import Foundation
import SwiftUI

struct Badge: Identifiable {
    let id = UUID()
    let identifier: String
    let color: Color
    let icon: String
    let name: String
    let goal: String
    let explanation: String
    let isLocked: Bool

    // Fortschritt (für Medaillen-Optik und Detailansicht)
    var level: Int = 0
    var maxLevel: Int = 10
    var currentValue: Int = 0
    var previousThreshold: Int = 0
    var nextThreshold: Int? = nil
    var unit: String = ""
    var isSpecial: Bool = false

    var tier: BadgeTier { isSpecial ? .special : BadgeTier(level: level) }

    /// Fortschritt zur nächsten Stufe (0…1), 1 bei Maximal-Level
    var progressToNext: Double {
        guard let next = nextThreshold else { return 1 }
        let span = max(next - previousThreshold, 1)
        return min(max(Double(currentValue - previousThreshold) / Double(span), 0), 1)
    }
}

/// Medaillen-Stufe abhängig vom Level
enum BadgeTier {
    case none, bronze, silver, gold, platinum, diamond, special

    init(level: Int) {
        switch level {
        case ...0:  self = .none
        case 1...2: self = .bronze
        case 3...4: self = .silver
        case 5...6: self = .gold
        case 7...8: self = .platinum
        default:    self = .diamond
        }
    }

    var name: String {
        switch self {
        case .none:     "Noch nicht erreicht"
        case .bronze:   "Bronze"
        case .silver:   "Silber"
        case .gold:     "Gold"
        case .platinum: "Platin"
        case .diamond:  "Diamant"
        case .special:  "Spezial"
        }
    }

    /// Metallischer Verlauf für den Rahmen
    var rimColors: [Color] {
        switch self {
        case .none:     [Color(white: 0.35), Color(white: 0.2)]
        case .bronze:   [Color(hex: "F0B27A"), Color(hex: "B87333"), Color(hex: "6E3B12")]
        case .silver:   [Color(hex: "F4F6F8"), Color(hex: "A7B0BA"), Color(hex: "5E6670")]
        case .gold:     [Color(hex: "FFF1B8"), Color(hex: "E3B23C"), Color(hex: "8A6212")]
        case .platinum: [Color(hex: "E8FBFF"), Color(hex: "8FD3E8"), Color(hex: "3C7E94")]
        case .diamond:  [Color(hex: "FFFFFF"), Color(hex: "B9A6FF"), Color(hex: "5B8CFF"), Color(hex: "35E0FF")]
        case .special:  [Color(hex: "B8FFF1"), Color(hex: "2EC4B6"), Color(hex: "0B6E66")]
        }
    }
}

enum BadgeType: String, CaseIterable {
    case streak, runden, fragen, richtige, falsche
    
    var thresholds: [Int] {
        switch self {
        case .streak:
            return [3, 7, 14, 21, 30, 45, 60, 90, 120, 180]
        case .runden:
            return [15, 30, 50, 75, 100, 150, 200, 300, 400, 500]
        case .fragen:
            return [100, 200, 350, 500, 700, 900, 1200, 1500, 2000, 2500]
        case .richtige:
            return [50, 100, 175, 250, 350, 450, 600, 750, 900, 1100]
        case .falsche:
            return [50, 100, 175, 250, 350, 450, 600, 750, 900, 1100]
        }
    }
    
    var name: String {
        switch self {
        case .streak: return "Durchhalter"
        case .runden: return "Dauerspieler"
        case .fragen: return "Wissensdurst"
        case .richtige: return "Volltreffer"
        case .falsche: return "Aus Fehlern lernen"
        }
    }

    /// Einheit für Texte wie „42 / 50 Tage in Folge“
    var unit: String {
        switch self {
        case .streak: return "Tage in Folge"
        case .runden: return "Runden gespielt"
        case .fragen: return "Fragen beantwortet"
        case .richtige: return "richtige Antworten"
        case .falsche: return "falsche Antworten"
        }
    }
    
    var icon: String {
        switch self {
        case .streak: return "flame.fill"
        case .runden: return "arrow.triangle.2.circlepath"
        case .fragen: return "books.vertical.fill"
        case .richtige: return "scope"
        case .falsche: return "arrow.uturn.up"
        }
    }
    
    var color: Color {
        switch self {
        case .streak: return .orange
        case .runden: return .yellow
        case .fragen: return .blue
        case .richtige: return .green
        case .falsche: return .red
        }
    }
}
