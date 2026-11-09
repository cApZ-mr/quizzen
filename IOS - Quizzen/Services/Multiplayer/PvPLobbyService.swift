//
//  PvPLobbyService.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 11.07.26.
//
//  Datenzugriff für Duelle. Alle Schreibzugriffe laufen über
//  Server-Funktionen (supabase/migrations/003_duels.sql).
//

import Foundation
import Supabase

// MARK: - Modelle

nonisolated struct Match: Codable, Identifiable, Equatable {
    let id: UUID
    let invite_code: String
    let host_id: UUID
    var guest_id: UUID?
    var status: String
    var quiz_id: String?
    var question_order: [Int]?
    var current_question_index: Int
    var host_score: Int
    var guest_score: Int
    let created_at: Date
    var question_started_at: Date?
    var question_duration: Int?
    var finished_at: Date?
    var left_by: UUID?
    /// Vom Host gewählte Einstellungen (nil = Standard: handverlesene Antworten)
    var settings: DuelSettings?
    /// Direkt eingeladener Freund (nil = Einladung per Code)
    var invited_id: UUID?

    enum Status: String {
        case waiting, active, finished, cancelled
    }

    var matchStatus: Status { Status(rawValue: status) ?? .waiting }
    var questionCount: Int { question_order?.count ?? 0 }
    var duration: Int { question_duration ?? 20 }
}

/// Einstellungen eines Duells, die beide Geräte zum Erzeugen der Antworten brauchen
nonisolated struct DuelSettings: Codable, Equatable {
    var answerCount: Int
    var distractors: String          // "random" | "similar"
    var label: String                // z. B. „Kenner“ oder „Eigene“
}

nonisolated struct MatchAnswer: Codable, Equatable {
    let user_id: UUID
    let question_index: Int
    let answer: String?
    let is_correct: Bool
    let answered_at: Date
}

nonisolated struct MatchState: Decodable {
    let match: Match
    let answers: [MatchAnswer]
    let server_time: Date
}

enum PvPLobbyError: LocalizedError {
    case codeNotFound
    case matchAlreadyFull
    case ownMatch
    case serverNotReady
    case other(String)

    var errorDescription: String? {
        switch self {
        case .codeNotFound:     "Kein offenes Duell mit diesem Code gefunden."
        case .matchAlreadyFull: "Diesem Duell ist bereits jemand beigetreten."
        case .ownMatch:         "Das ist dein eigenes Duell – teile den Code mit einem Freund."
        case .serverNotReady:   "Der Duell-Server ist noch nicht eingerichtet (Migration 003 fehlt)."
        case .other(let text):  text
        }
    }

    /// Übersetzt Server-Fehler (raise exception '…') in verständliche Meldungen.
    static func from(_ error: Error) -> PvPLobbyError {
        let text = String(describing: error)
        if text.contains("code_not_found") { return .codeNotFound }
        if text.contains("match_full") { return .matchAlreadyFull }
        if text.contains("own_match") { return .ownMatch }
        if text.contains("PGRST202") || text.contains("Could not find the function") { return .serverNotReady }
        return .other(error.localizedDescription)
    }
}

// MARK: - Service

final class PvPLobbyService {

    private struct MatchInsert: Encodable {
        let invite_code: String
        let host_id: String
        let status: String
        let invited_id: String?   // nil wird weggelassen (Spalte erst ab Migration 006)
    }

    /// Erstellt ein neues Duell. Bei Code-Kollision (Unique-Index) wird neu gewürfelt.
    func createMatch(inviting invitedId: UUID? = nil) async throws -> Match {
        let hostId = try await supabase.auth.session.user.id
        var lastError: Error?

        for _ in 0..<5 {
            let insert = MatchInsert(invite_code: Self.generateInviteCode(), host_id: hostId.uuidString,
                                     status: "waiting", invited_id: invitedId?.uuidString)
            do {
                return try await supabase
                    .from("matches")
                    .insert(insert)
                    .select()
                    .single()
                    .execute()
                    .value
            } catch let error as PostgrestError where error.code == "23505" {
                lastError = error
            }
        }
        throw lastError ?? PvPLobbyError.other("Duell konnte nicht erstellt werden.")
    }

    func joinMatch(code: String) async throws -> Match {
        do {
            return try await supabase.rpc("join_match", params: ["p_code": code]).execute().value
        } catch {
            throw PvPLobbyError.from(error)
        }
    }

    func startMatch(matchId: UUID, quizId: String, questionOrder: [Int], duration: Int, settings: DuelSettings) async throws {
        struct Params: Encodable {
            let p_match_id: UUID
            let p_quiz_id: String
            let p_question_order: [Int]
            let p_duration: Int
            let p_settings: DuelSettings
        }
        do {
            try await supabase.rpc("start_match", params: Params(p_match_id: matchId, p_quiz_id: quizId,
                                                                 p_question_order: questionOrder,
                                                                 p_duration: duration, p_settings: settings))
                .execute()
        } catch {
            throw PvPLobbyError.from(error)
        }
    }

    func submitAnswer(matchId: UUID, questionIndex: Int, answer: String?, isCorrect: Bool) async throws {
        struct Params: Encodable {
            let p_match_id: UUID
            let p_question_index: Int
            let p_answer: String?
            let p_is_correct: Bool

            // nil MUSS als JSON-null gesendet werden – der synthetisierte Encoder
            // würde den Schlüssel weglassen, und Supabase fände die Funktion nicht.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_match_id, forKey: .p_match_id)
                try c.encode(p_question_index, forKey: .p_question_index)
                try c.encode(p_answer, forKey: .p_answer)
                try c.encode(p_is_correct, forKey: .p_is_correct)
            }
            enum CodingKeys: String, CodingKey { case p_match_id, p_question_index, p_answer, p_is_correct }
        }
        try await supabase.rpc("submit_answer", params: Params(p_match_id: matchId, p_question_index: questionIndex,
                                                               p_answer: answer, p_is_correct: isCorrect))
            .execute()
    }

    func advance(matchId: UUID, fromIndex: Int) async throws {
        struct Params: Encodable {
            let p_match_id: UUID
            let p_from_index: Int
        }
        try await supabase.rpc("advance_match", params: Params(p_match_id: matchId, p_from_index: fromIndex)).execute()
    }

    func leave(matchId: UUID) async throws {
        do {
            try await supabase.rpc("leave_match", params: ["p_match_id": matchId.uuidString]).execute()
        } catch {
            log.error("leave_match fehlgeschlagen: \(String(describing: error))")
            throw error
        }
    }

    func fetchState(matchId: UUID) async throws -> MatchState {
        try await supabase.rpc("match_state", params: ["p_match_id": matchId.uuidString]).execute().value
    }

    /// Offene Duell-Einladungen an mich (max. 30 Minuten alt)
    func fetchInvitations() async throws -> [Match] {
        let myId = try await supabase.auth.session.user.id.uuidString
        return try await supabase
            .from("matches")
            .select()
            .eq("invited_id", value: myId)
            .eq("status", value: "waiting")
            .is("guest_id", value: nil)
            .gte("created_at", value: Date().addingTimeInterval(-30 * 60))
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Eigenes offenes Duell (z. B. nach App-Neustart), max. 2 Stunden alt
    func fetchMyOpenMatch() async throws -> Match? {
        let myId = try await supabase.auth.session.user.id.uuidString
        let since = Date().addingTimeInterval(-2 * 3600)
        let matches: [Match] = try await supabase
            .from("matches")
            .select()
            .or("host_id.eq.\(myId),guest_id.eq.\(myId)")
            .in("status", values: ["waiting", "active"])
            .gte("created_at", value: since)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return matches.first
    }

    func fetchAccounts(ids: [UUID]) async throws -> [Account] {
        guard !ids.isEmpty else { return [] }
        return try await supabase
            .from("accounts")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
    }

    /// 6-stelliger Zahlencode
    private static func generateInviteCode() -> String {
        String((0..<6).map { _ in "0123456789".randomElement()! })
    }
}
