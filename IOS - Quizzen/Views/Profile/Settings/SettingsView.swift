//
//  SettingsView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 11.06.26.
//

import Foundation
import SwiftUI

// MARK: - Datenmodelle
struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - Hilfs View
struct SettingsRow: View {
    let icon: String
    let title: String
    var iconColor: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title).padding(.leading, 8)
        }
    }
}


// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var viewModel: UserViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var statsManager: StatsManager
    @Environment(\.openURL) private var openURL


    @State private var showSocialSheet = false
    @State private var showReviewSheet = false

    @State private var showLogoutConformation = false
    @State private var isLoggingOut = false
    @State private var errorMessage: String?
    
    @State private var searchText = ""
    @State private var expandedID: FAQItem.ID? = nil
    

    private let faqItems: [FAQItem] = [
        FAQItem(question: "Wie funktionieren die Schwierigkeitsstufen?",
                answer: "Jedes Quiz hat mehrere Stufen von Leicht bis Extrem. Sie unterscheiden sich in Fragenauswahl, Anzahl der Antworten und Zeitlimit. Unter „Eigene“ stellst du dir deine Runde selbst zusammen – z. B. nur bestimmte Regionen oder nur Fragen, die du noch nicht kannst."),

        FAQItem(question: "Muss ich Quizze freischalten?",
                answer: "Nein, alle Quizze und Stufen sind sofort verfügbar. Nur einige Profil-Banner werden über dein Level freigeschaltet."),

        FAQItem(question: "Gibt es regelmäßig neue Quizze oder Inhalte?",
                answer: "Ja, das Quizzen-Team erweitert die App laufend um neue Quizze und Fragen. Es lohnt sich also, ab und zu vorbeizuschauen."),

        FAQItem(question: "Wie funktionieren die Abzeichen – wofür bekomme ich sie und wo sehe ich meinen Fortschritt?",
                answer: "Die Abzeichen sind eine visuelle Darstellung deines Fortschritts. Je mehr du quizzt, desto mehr levelst du deine Abzeichen hoch. Deinen aktuellen Stand kannst du jederzeit in deinem Profil einsehen."),

        FAQItem(question: "Ist die App für Kinder geeignet bzw. gibt es einen Kindermodus/Altersfreigabe?",
                answer: "Die App ist für jedes Alter geeignet. Alle fragen sind FSK0 und für jedes Alter geeignet."),

        FAQItem(question: "Kann ich gegen Freunde oder andere Spieler antreten (Multiplayer/Duell-Modus)?",
                answer: "Ja! Fordere einen Freund direkt aus seinem Profil heraus oder erstelle im Tab „Duell“ ein Duell und teile den 6-stelligen Code. Du wählst Quiz, Stufe oder eigene Einstellungen – ihr bekommt dieselben Fragen und seht nach jeder Frage, wer richtig lag."),

        FAQItem(question: "Wie melde oder blockiere ich andere Spieler?",
                answer: "Öffne das Profil der Person und tippe oben rechts auf „…“. Dort kannst du sie melden oder blockieren. Blockierte Nutzer verwaltest du in den Einstellungen unter „Blockierte Nutzer“."),

        FAQItem(question: "Ist die App komplett kostenlos, oder gibt es Werbung und In-App-Käufe (z. B. Premium-Quizze)?",
                answer: "Aktuell ist die App komplett kosten- und werbefrei. Quizzen behält sich aber vor, dies zukünftig aus Gründen der Kostendeckung zu ändern."),

        FAQItem(question: "Gibt es eine Bestenliste – global, unter Freunden oder pro Quiz?",
                answer: "Ja. Im Tab „Bestenliste“ vergleichst du dich weltweit, mit Freunden oder in deinem Land – nach richtigen Antworten, Runden, Streaks oder Punkten pro Quiz."),

        FAQItem(question: "Wie kann ich eine falsche Antwort oder eine fehlerhafte Frage melden?",
                answer: "Direkt an der Fragenbox findest du einen blauen Kreis, über den du die Frage melden kannst."),

        FAQItem(question: "Funktioniert Quizzen offline, z. B. unterwegs ohne Internet?",
                answer: "Ja, Quizzen ist eine reine Offline-App und funktioniert ohne Internetverbindung."),

        FAQItem(question: "Wie setze ich meinen Fortschritt/meine Statistik zurück oder lösche mein Konto?",
                answer: "In den Einstellungen kannst du unter 'Account' dein Konto löschen und unter 'Statistiken' deine Statistiken zurücksetzen."),
    ]
    
    private var filteredFAQ: [FAQItem] {
        guard !searchText.isEmpty else { return faqItems }
        return faqItems.filter {
            $0.question.localizedCaseInsensitiveContains(searchText) ||
            $0.answer.localizedCaseInsensitiveContains(searchText)
        }
    }

    @AppStorage(StreakReminder.enabledKey) private var reminderEnabled = false
    @State private var reminderDenied = false

    private func setReminder(_ enabled: Bool) async {
        if enabled {
            let granted = await StreakReminder.requestPermission()
            reminderDenied = !granted
            reminderEnabled = granted
        } else {
            reminderEnabled = false
        }
        StreakReminder.reschedule(stats: statsManager.globalManager.stats)
    }

    var body: some View {
        List {
            // Account Section
            Section() {
                NavigationLink(destination: AccountSettingsView()) {
                    SettingsRow(icon: "person.crop.circle", title: "Accountdaten")
                }
            }
            
            // Benachrichtigungen
            Section {
                Toggle(isOn: Binding(
                    get: { reminderEnabled },
                    set: { newValue in Task { await setReminder(newValue) } }
                )) {
                    SettingsRow(icon: "bell.badge.fill", title: "Streak-Erinnerung (19 Uhr)", iconColor: .orange)
                }
                .tint(.orange)
            } footer: {
                Text(reminderDenied
                     ? "Benachrichtigungen sind in den iOS-Einstellungen für Quizzen ausgeschaltet."
                     : "Erinnert dich abends, wenn du heute noch nicht gespielt hast.")
            }

            // Daten Section
            Section() {
                NavigationLink(destination: DeleteAccountView()) {
                    SettingsRow(icon: "person.crop.circle", title: "Account")
                }

                NavigationLink(destination: ResetStatsView()) {
                    SettingsRow(icon: "chart.xyaxis.line", title: "Statistiken")
                }
                NavigationLink(destination: BlockedUsersView()) {
                    SettingsRow(icon: "hand.raised", title: "Blockierte Nutzer")
                }

                /*NavigationLink(destination: SelectLanguageView()) {
                    SettingsRow(icon: "bubble", title: "Sprache")
                }*/
            }
            
            Section {
                faqSection
            }

            Section {
                NavigationLink(destination: FeedbackView()) {
                    SettingsRow(icon: "bubble.left.and.bubble.right.fill", title: "Feedback", iconColor: .blue)
                }
                NavigationLink(destination: ReportView()) {
                    SettingsRow(icon: "ant.fill", title: "Fehler melden", iconColor: .orange)
                }
            }

            Section {
                legalRow(icon: "hand.raised.circle", title: "Datenschutzerklärung", url: AppLinks.privacyPolicy)
                legalRow(icon: "doc.text", title: "Nutzungsbedingungen", url: AppLinks.terms)
            } header: {
                Text("Rechtliches")
            }
            
            Section() {
                Button(role: .destructive) {
                    showLogoutConformation = true
                } label: {
                    HStack {
                        if isLoggingOut {
                            ProgressView()
                        } else {
                            Text("Abmelden")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoggingOut)
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .alert("Bist du absolut sicher?", isPresented: $showLogoutConformation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Ausloggen", role: .destructive) {
                Task { await logoutSettings() }
            }
        } message: {
            Text("Wenn du dich ausloggst, dann musst du dich wieder einloggen oder dir einen neuen Account erstellen um die App nutzen zu können.")
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    
    // MARK: FAQ
    @ViewBuilder
    private func legalRow(icon: String, title: String, url: URL?) -> some View {
        if let url {
            Button { openURL(url) } label: {
                HStack {
                    SettingsRow(icon: icon, title: title)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Häufige fragen")
                .font(.system(.footnote))
                .foregroundColor(.gray)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(filteredFAQ.enumerated()), id: \.element.id) { index, item in
                    FAQRow(
                        item: item,
                        isExpanded: expandedID == item.id,
                        isLast: index == filteredFAQ.count - 1
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedID = (expandedID == item.id) ? nil : item.id
                        }
                    }
                }

                if filteredFAQ.isEmpty {
                    Text("Keine Treffer für „\(searchText)“")
                        .font(.system(.subheadline))
                        .foregroundColor(.gray)
                        .padding(16)
                }
            }
            .background(Color(white: 0.11))
            .cornerRadius(14)
        }
    }

    // MARK: Contact
    private var contactSection: some View {
        Section() {
            NavigationLink(destination: FeedbackView()) {
                SettingsRow(icon: "bubble.left.and.bubble.right.fill", title: "Feedback")
                    .foregroundColor(.blue)
            }
            
            NavigationLink(destination: ReportView()) {
                SettingsRow(icon: "ant.fill", title: "Fehler melden")
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Logout-Logik (jetzt korrekt auf Struct-Ebene, außerhalb von body)
    private func logoutSettings() async {
        isLoggingOut = true
        errorMessage = nil
        do {
            try await authViewModel.logout()
        } catch {
            errorMessage = "Abmelden fehlgeschlagen"
        }
        isLoggingOut = false
    }
}

// MARK: - FAQ Row
private struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(item.question)
                        .font(.system(.subheadline))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(isExpanded ? .blue : Color(white: 0.4))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.system(.footnote))
                    .foregroundColor(Color(white: 0.65))
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !isLast {
                Divider()
                    .background(Color(white: 0.17))
                    .padding(.leading, 16)
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Contact Row
private struct ContactRow<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let isLast: Bool
    let destination: Destination
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: destination) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(.title3))
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.system(.subheadline))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if !isLast {
                Divider()
                    .background(Color(white: 0.17))
                    .padding(.leading, 16)
            }
        }
    }
}
