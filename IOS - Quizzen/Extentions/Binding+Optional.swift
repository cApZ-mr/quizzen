//
//  Binding+Optional.swift
//  IOS - Quizzen
//

import SwiftUI

extension Binding {
    /// `true`, solange ein Wert vorhanden ist. Wird der Alert geschlossen,
    /// wird der Wert auf `nil` gesetzt. Ersatz für `.constant(x != nil)`.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { if !$0 { wrappedValue = nil } }
        )
    }
}
