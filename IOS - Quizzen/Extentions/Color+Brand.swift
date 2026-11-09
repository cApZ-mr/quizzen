//
//  Color+Brand.swift
//  IOS - Quizzen
//

import SwiftUI

extension Color {
    /// Quizzen-Markenblau (#004AAD)
    nonisolated static let brand = Color(hex: "004AAD")
    /// Helleres Blau für Verläufe (#0066E0)
    nonisolated static let brandLight = Color(hex: "0066E0")

    nonisolated init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: Double(rgbValue & 0x0000FF) / 255.0)
    }
}
