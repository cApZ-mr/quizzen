//
//  Moderation.swift
//  IOS - Quizzen
//
//  Nutzer melden und blockieren, Filter für Benutzernamen
//  (App-Store-Richtlinie 1.2 für nutzergenerierte Inhalte).
//  Serverseitig abgesichert durch supabase/migrations/008_moderation.sql.
//

import Foundation
import Combine
import Supabase

// MARK: - Benutzernamen-Filter

nonisolated enum UsernameFilter {
    /// Gleiche Liste wie `is_offensive_username` in 008_moderation.sql
    static let blockedFragments = [
        "fick", "fotze", "hurensohn", "hure", "nutte", "wichser", "wixxer", "schlampe",
        "missgeburt", "spast", "behindert", "schwuchtel", "kanake", "neger", "nigger",
        "nigga", "hitler", "siegheil", "arschloch", "titten", "kinderficker",
        "vergewaltig", "fuck", "shit", "bitch", "cunt", "whore", "slut", "faggot",
        "retard", "rapist", "pedophil", "paedophil", "pädophil", "porn", "penis", "vagina",
    ]

    private static let leet: [Character: Character] = [
        "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b",
        "@": "a", "$": "s", "!": "i", "|": "i",
    ]

    /// Kleinbuchstaben, Leetspeak aufgelöst, nur Buchstaben
    static func normalize(_ name: String) -> String {
        let lowered = name.lowercased()
        let mapped = String(lowered.map { leet[$0] ?? $0 })
        return String(mapped.filter { $0.isLetter && ("a"..."z" ~= $0 || "äöüß".contains($0)) })
    }

    static func isOffensive(_ name: String) -> Bool {
        let normalized = normalize(name)
        return blockedFragments.contains { normalized.contains($0) }
    }

    /// Fehlermeldung für die Eingabe oder nil, wenn der Name in Ordnung ist
    static func validationError(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 { return "Benutzername muss mind. 3 Zeichen haben" }
        if trimmed.count > 20 { return "Benutzername darf höchstens 20 Zeichen haben" }
        if isOffensive(trimmed) { return "Dieser Benutzername ist nicht erlaubt" }
        return nil
    }
}

// MARK: - Meldegründe

enum UserReportReason: String, CaseIterable, Identifiable {
    case username = "Anstößiger Benutzername"
    case avatar = "Anstößiges Profilbild"
    case harassment = "Belästigung oder Beleidigung"
    case cheating = "Schummeln"
    case other = "Sonstiges"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .username: "textformat"
        case .avatar: "photo"
        case .harassment: "exclamationmark.bubble"
        case .cheating: "wand.and.stars"
        case .other: "ellipsis.circle"
        }
    }
}

// MARK: - Supabase

extension SupabaseClient {
    func reportUser(_ userId: UUID, reason: UserReportReason, message: String?) async throws {
        let myId = try await auth.session.user.id
        struct NewReport: Encodable {
            let reporter_id: String
            let reported_id: String
            let reason: String
            let message: String?
        }
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await from("user_reports")
            .insert(NewReport(reporter_id: myId.uuidString,
                              reported_id: userId.uuidString,
                              reason: reason.rawValue,
                              message: (trimmed?.isEmpty ?? true) ? nil : String(trimmed!.prefix(1000))))
            .execute()
    }

    func blockUser(_ userId: UUID) async throws {
        try await rpc("block_user", params: ["p_user": userId.uuidString]).execute()
    }

    func unblockUser(_ userId: UUID) async throws {
        try await rpc("unblock_user", params: ["p_user": userId.uuidString]).execute()
    }

    /// Nutzer, die ich blockiert habe oder die mich blockiert haben
    func fetchBlockRelations() async throws -> Set<UUID> {
        let ids: [UUID] = try await rpc("my_block_relations").execute().value
        return Set(ids)
    }

    /// Von mir blockierte Nutzer (für die Verwaltung in den Einstellungen)
    func fetchBlockedAccounts() async throws -> [Account] {
        let myId = try await auth.session.user.id
        struct Row: Decodable { let blocked_id: UUID }
        let rows: [Row] = try await from("user_blocks")
            .select("blocked_id")
            .eq("blocker_id", value: myId.uuidString)
            .execute()
            .value
        guard !rows.isEmpty else { return [] }
        return try await from("accounts")
            .select()
            .in("id", values: rows.map { $0.blocked_id.uuidString })
            .order("username")
            .execute()
            .value
    }
}

// MARK: - Gemeinsamer Zustand

/// Hält die Blockier-Beziehungen, damit Suche, Vorschläge, Einladungen
/// und Anfragen blockierte Nutzer ausblenden können.
@MainActor
final class BlockList: ObservableObject {
    static let shared = BlockList()

    @Published private(set) var hiddenIds: Set<UUID> = []

    func refresh() async {
        do {
            hiddenIds = try await supabase.fetchBlockRelations()
        } catch {
            // Migration 008 evtl. noch nicht ausgeführt – dann einfach nichts ausblenden
            log.error("Blockliste konnte nicht geladen werden: \(error.localizedDescription)")
        }
    }

    func isHidden(_ id: UUID) -> Bool { hiddenIds.contains(id) }

    func block(_ id: UUID) async throws {
        try await supabase.blockUser(id)
        hiddenIds.insert(id)
    }

    func unblock(_ id: UUID) async throws {
        try await supabase.unblockUser(id)
        await refresh()
    }
}
