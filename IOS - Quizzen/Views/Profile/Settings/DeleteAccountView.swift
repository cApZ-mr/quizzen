//
//  DeleteAccountView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 24.06.26.
//

import Foundation
import SwiftUI
import Supabase

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: UserViewModel
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var showConfirmationAlert = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: - Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                        .padding(.top, 8)

                    Text("Konto wirklich löschen?")
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
                    Text("Das passiert, wenn du dein Konto löschst:")
                        .font(.headline)

                    ConsequenceRow(
                        icon: "chart.bar.xaxis",
                        title: "Alle Statistiken gehen verloren",
                        description: "Deine gesamten Verlaufsdaten und Auswertungen werden unwiderruflich gelöscht."
                    )

                    ConsequenceRow(
                        icon: "flag.checkered",
                        title: "Dein gesamter Fortschritt wird gelöscht",
                        description: "Erreichte Ziele, Level, Erfolge und gesammelte Punkte sind danach nicht mehr abrufbar."
                    )

                    ConsequenceRow(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "Persönliche Einstellungen verschwinden",
                        description: "Individuelle Anpassungen, Präferenzen und personalisierte Inhalte werden vollständig entfernt."
                    )

                    ConsequenceRow(
                        icon: "trash",
                        title: "Endgültige Löschung",
                        description: "Alle Daten werden unwiederruflich entfernt und können nicht wiederhergestellt werden."
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.08))
                )

                VStack(alignment: .leading) {
                    Button {
                        // TODO: Link zu echter URL öffnen
                        log.debug("zu den Datenschutzrichtlinien")
                    } label: {
                        Text("Unsere Datenschutzrichtlinien").font(.footnote)
                    }

                    Button {
                        // TODO: Link zu echter URL öffnen
                        log.debug("zu den AGB's")
                    } label: {
                        Text("Unsere AGB's").font(.footnote)
                    }
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // MARK: - Buttons
                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        showConfirmationAlert = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Konto endgültig löschen")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeleting)

                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Konto löschen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Bist du absolut sicher?", isPresented: $showConfirmationAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Endgültig löschen", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Dein Konto sowie alle Statistiken, Fortschritte und persönlichen Einstellungen werden unwiderruflich gelöscht.")
        }
    }

    // MARK: - Aktion
    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil

        do {
            try await supabase.rpc("delete_own_account").execute()
        } catch {
            log.error("RPC-Fehler beim Löschen: \(error.localizedDescription)")
            errorMessage = "Löschen fehlgeschlagen. Bitte versuch es erneut."
            isDeleting = false
            return
        }

        // Account ist weg – lokale Daten leeren und Session beenden.
        // (MainView räumt beim Logout zusätzlich Profil-Daten auf.)
        statsManager.resetAll()
        try? await authViewModel.logout()
        dismiss()
        isDeleting = false

    }
    
    
}

#Preview {
    NavigationStack {
        DeleteAccountView()
    }
}
