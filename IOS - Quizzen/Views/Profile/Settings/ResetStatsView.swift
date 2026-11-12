//
//  ResetStatsView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 24.06.26.
//

import Foundation
import SwiftUI

struct ResetStatsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var statsManager: StatsManager
        
    @State private var showConfirmationAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                        .padding(.top, 8)

                    Text("Statistiken zurücksetzten")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Diese Aktion kann nicht rückgängig gemacht werden.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                // MARK: - Was passiert beim Löschen
                VStack(alignment: .leading, spacing: 16) {
                    Text("Das passiert, wenn du deine Statistiken zurücksetzt:")
                        .font(.headline)

                    ConsequenceRow(
                        icon: "flame.fill",
                        title: String(localized: "Tägliche Streak geht verloren"),
                        description: String(localized: "Deine Tägliche Aktivitätsstreak geht verloren und wird auf 0 gesetzt.")
                    )

                    ConsequenceRow(
                        icon: "lock.shield.fill",
                        title: String(localized: "Erspielte Abzeichen"),
                        description: String(localized: "Alle deine erspielten Abzeichen gehen verloren und werden auf 0 zurückgesetzt.")
                    )

                    ConsequenceRow(
                        icon: "flag.checkered",
                        title: String(localized: "Quiz Statistiken"),
                        description: String(localized: "Deine Statistiken für die Quizze werden allesamt auf 0 zurückgesetzt.")
                    )

                    ConsequenceRow(
                        icon: "trash",
                        title: String(localized: "Endgültige Löschung"),
                        description: String(localized: "Alle Daten werden unwiederruflich entfernt und können nicht wiederhergestellt werden.")
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.08))
                )
                
                
                VStack(alignment: .leading) {
                    LegalLinkButton(title: String(localized: "Unsere Datenschutzrichtlinien"), url: AppLinks.privacyPolicy)
                    
                    LegalLinkButton(title: String(localized: "Unsere AGB"), url: AppLinks.terms)
                }
                .padding(.horizontal)
                
                
                Spacer()
                
                // MARK: - Buttons
                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        showConfirmationAlert = true
                    } label: {
                        Text("Statistiken zurücksetzten")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Statistiken")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Bist du absolut sicher?", isPresented: $showConfirmationAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Endgültig löschen", role: .destructive) {
                resetStats()
            }
        } message: {
            Text("Alle deine Statistiken werden unwiederruflich zurückgesetzt und können nicht wiederhergesdtellt werden.")
        }
    }

    // MARK: - Helper View
    @ViewBuilder
    private func consequenceRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.red)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Aktion
    private func resetStats() {
        // MARK: Statistiken Löschen
        statsManager.resetAll()

        dismiss()
    }
}



#Preview {
    NavigationStack {
        ResetStatsView()
    }
}

