//
//  BlockedUsersView.swift
//  IOS - Quizzen
//
//  Liste der von mir blockierten Nutzer mit „Aufheben“.
//

import SwiftUI

struct BlockedUsersView: View {
    @State private var accounts: [Account] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if accounts.isEmpty {
                ContentUnavailableView("Niemand blockiert",
                                       systemImage: "hand.raised",
                                       description: Text("Blockieren kannst du über „…“ oben rechts in einem Profil."))
            } else {
                Section {
                    ForEach(accounts) { account in
                        HStack(spacing: 12) {
                            AvatarView(username: account.username, url: account.avatarUrl, size: 40)
                            Text(account.username).font(.body.weight(.medium))
                            Spacer()
                            Button("Aufheben") { Task { await unblock(account) } }
                                .buttonStyle(.bordered)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                } footer: {
                    Text("Blockierte Nutzer sehen dich nicht in der Suche, können dir keine Anfragen schicken und dich nicht zum Duell einladen.")
                }
            }
        }
        .navigationTitle("Blockierte Nutzer")
        .alert("Fehler", isPresented: $errorMessage.isPresent()) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        do {
            accounts = try await supabase.fetchBlockedAccounts()
        } catch {
            log.error("Blockierte Nutzer konnten nicht geladen werden: \(error.localizedDescription)")
            errorMessage = String(localized: "Die Liste konnte nicht geladen werden.")
        }
    }

    private func unblock(_ account: Account) async {
        do {
            try await BlockList.shared.unblock(account.id)
            withAnimation { accounts.removeAll { $0.id == account.id } }
        } catch {
            log.error("Entblocken fehlgeschlagen: \(error.localizedDescription)")
            errorMessage = String(localized: "Das hat nicht geklappt. Bitte versuch es erneut.")
        }
    }
}
