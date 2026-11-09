//
//  AppLinks.swift
//  IOS - Quizzen
//
//  Zentrale Links (Google-Sites-Seite von Quizzen).
//

import SwiftUI

enum AppLinks {
    /// Datenschutzerklärung (steht auf der Startseite)
    static let privacyPolicy: URL? = URL(string: "https://sites.google.com/view/quizzen-app/startseite")
    /// Nutzungsbedingungen
    static let terms: URL? = URL(string: "https://sites.google.com/view/quizzen-app/nutzungsbedingungen")
    /// Website (im Profil unter „Mehr von Quizzen“)
    static let website: URL? = URL(string: "https://sites.google.com/view/quizzen-app/startseite")
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
