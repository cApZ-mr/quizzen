//
//  AppLinks.swift
//  IOS - Quizzen
//
//  Zentrale Links. ⚠️ Vor dem Release ausfüllen: Apple verlangt eine
//  erreichbare Datenschutzerklärung (die Domain quizzen-app.de existiert
//  derzeit nicht).
//

import SwiftUI

enum AppLinks {
    /// TODO: echte URL eintragen
    static let privacyPolicy: URL? = nil
    /// TODO: echte URL eintragen
    static let terms: URL? = nil
    /// TODO: echte URL eintragen (wird im Profil unter „Mehr von Quizzen“ angezeigt)
    static let website: URL? = nil
}

/// Link-Button, der bei fehlender URL einen Hinweis statt nichts zeigt
struct LegalLinkButton: View {
    let title: String
    let url: URL?
    @Environment(\.openURL) private var openURL
    @State private var showMissing = false

    var body: some View {
        Button {
            if let url { openURL(url) } else { showMissing = true }
        } label: {
            Text(title).font(.footnote)
        }
        .alert("Noch nicht verfügbar", isPresented: $showMissing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Dieser Link wird gerade eingerichtet. Bei Fragen erreichst du uns über „Feedback“ in den Einstellungen.")
        }
    }
}
