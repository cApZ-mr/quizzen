//
//  ReportUserSheet.swift
//  IOS - Quizzen
//
//  Nutzer melden (Grund + optionale Beschreibung, optional direkt blockieren).
//

import SwiftUI

struct ReportUserSheet: View {
    let account: Account
    /// Wird nach erfolgreichem Senden aufgerufen; Parameter: zusätzlich blockieren?
    let onSent: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: UserReportReason?
    @State private var message = ""
    @State private var alsoBlock = true
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(UserReportReason.allCases) { item in
                        Button {
                            reason = item
                        } label: {
                            HStack {
                                Label {
                                    Text(item.rawValue).foregroundStyle(.primary)
                                } icon: {
                                    Image(systemName: item.icon).foregroundStyle(Color.brand)
                                }
                                Spacer()
                                if reason == item {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(reason == item ? .isSelected : [])
                    }
                } header: {
                    Text("Warum meldest du \(account.username)?")
                }

                Section {
                    TextField("Was ist passiert? (optional)", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: message) { _, new in
                            if new.count > 1000 { message = String(new.prefix(1000)) }
                        }
                }

                Section {
                    Toggle("\(account.username) auch blockieren", isOn: $alsoBlock)
                } footer: {
                    Text("Meldungen sind anonym. Wir prüfen sie und entfernen Inhalte, die gegen unsere Regeln verstoßen.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nutzer melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Senden") { Task { await send() } }
                            .disabled(reason == nil)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func send() async {
        guard let reason else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await supabase.reportUser(account.id, reason: reason, message: message)
            onSent(alsoBlock)
            dismiss()
        } catch {
            log.error("Meldung fehlgeschlagen: \(error.localizedDescription)")
            errorMessage = "Die Meldung konnte nicht gesendet werden. Bitte versuch es erneut."
        }
    }
}
