//
//  LobbyService.swift
//  IOS - Quizzen
//
//  Datenzugriff für die Duell-Lobby (bis zu 10 Personen, mehrere Runden
//  hintereinander, auch mit wechselndem Quiz). Alle Schreibzugriffe laufen
//  über Server-Funktionen (supabase/migrations/012_lobbies.sql).
//

import Foundation
import Supabase

/// Deterministischer Zufallsgenerator (SplitMix64): gleicher Startwert →
/// gleiche Folge auf allen Geräten.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

nonisolated struct LobbyPresenceState: Codable {
    let userId: String
}

/// Einstellungen einer Runde, die alle Geräte zum Erzeugen der Antworten brauchen
nonisolated struct DuelSettings: Codable, Equatable {
    var answerCount: Int
    var distractors: String          // "random" | "similar"
    var label: String                // z. B. „Kenner" oder „Eigene"
}

// MARK: - Modelle

nonisolated struct Lobby: Codable, Identifiable, Equatable {
    let id: UUID
    let invite_code: String
    var host_id: UUID
    var status: String
    var quiz_id: String?
    var question_order: [Int]?
    var round_number: Int
    var current_question_index: Int
    var question_started_at: Date?
    var question_duration: Int
    var settings: DuelSettings?
    var max_players: Int
    var round_finished_at: Date?
    let created_at: Date
    var closed_at: Date?

    enum Status: String {
        case open, playing, closed
    }

    var lobbyStatus: Status { Status(rawValue: status) ?? .open }
    var questionCount: Int { question_order?.count ?? 0 }
    var duration: Int { question_duration }
}

nonisolated struct LobbyMember: Codable, Identifiable, Equatable {
    let user_id: UUID
    let username: String
    let avatar_url: String?
    let country: String?
    let joined_at: Date
    let left_at: Date?
    let is_host: Bool
    let total_correct: Int

    var id: UUID { user_id }
    var isActive: Bool { left_at == nil }
    var account: Account { Account(id: user_id, username: username, avatarUrl: avatar_url, country: country, createdAt: joined_at) }
}

nonisolated struct LobbyAnswer: Codable, Equatable {
    let user_id: UUID
    let question_index: Int
    let answer: String?
    let is_correct: Bool
    let answered_at: Date
}

nonisolated struct LobbyStateResponse: Decodable {
    let lobby: Lobby
    let members: [LobbyMember]
    let answers: [LobbyAnswer]
    let server_time: Date
}

nonisolated struct LobbyInvite: Codable, Identifiable {
    let lobby_id: UUID
    let invite_code: String
    let status: String
    let invited_by: UUID
    let inviter_username: String
    let inviter_avatar_url: String?
    let created_at: Date

    var id: UUID { lobby_id }
}

enum LobbyError: LocalizedError {
    case codeNotFound
    case lobbyFull
    case notEnoughPlayers
    case roundAlreadyRunning
    case notHost
    case serverNotReady
    case other(String)

    var errorDescription: String? {
        switch self {
        case .codeNotFound:        String(localized: "Keine offene Lobby mit diesem Code gefunden.")
        case .lobbyFull:           String(localized: "Diese Lobby ist bereits voll.")
        case .notEnoughPlayers:    String(localized: "Wartet noch auf mindestens eine weitere Person.")
        case .roundAlreadyRunning: String(localized: "Es läuft schon eine Runde.")
        case .notHost:             String(localized: "Nur der Host kann das.")
        case .serverNotReady:      String(localized: "Der Lobby-Server ist noch nicht eingerichtet (Migration 012 fehlt).")
        case .other(let text):     text
        }
    }

    /// Übersetzt Server-Fehler (raise exception '…') in verständliche Meldungen.
    static func from(_ error: Error) -> LobbyError {
        let text = String(describing: error)
        if text.contains("code_not_found")        { return .codeNotFound }
        if text.contains("lobby_full")             { return .lobbyFull }
        if text.contains("not_enough_players")     { return .notEnoughPlayers }
        if text.contains("round_already_running")  { return .roundAlreadyRunning }
        if text.contains("not_host")               { return .notHost }
        if text.contains("PGRST202") || text.contains("Could not find the function") { return .serverNotReady }
        return .other(error.localizedDescription)
    }
}

// MARK: - Service

final class LobbyService {

    func createLobby() async throws -> Lobby {
        do {
            return try await supabase.rpc("create_lobby").execute().value
        } catch {
            throw LobbyError.from(error)
        }
    }

    func joinLobby(code: String) async throws -> Lobby {
        do {
            return try await supabase.rpc("join_lobby", params: ["p_code": code]).execute().value
        } catch {
            throw LobbyError.from(error)
        }
    }

    func startRound(lobbyId: UUID, quizId: String, questionOrder: [Int], duration: Int, settings: DuelSettings) async throws {
        struct Params: Encodable {
            let p_lobby_id: UUID
            let p_quiz_id: String
            let p_question_order: [Int]
            let p_duration: Int
            let p_settings: DuelSettings
        }
        do {
            try await supabase.rpc("start_round", params: Params(p_lobby_id: lobbyId, p_quiz_id: quizId,
                                                                  p_question_order: questionOrder,
                                                                  p_duration: duration, p_settings: settings))
                .execute()
        } catch {
            throw LobbyError.from(error)
        }
    }

    func submitAnswer(lobbyId: UUID, questionIndex: Int, answer: String?, isCorrect: Bool) async throws {
        struct Params: Encodable {
            let p_lobby_id: UUID
            let p_question_index: Int
            let p_answer: String?
            let p_is_correct: Bool

            // nil MUSS als JSON-null gesendet werden – sonst fände Supabase die Funktion nicht.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_lobby_id, forKey: .p_lobby_id)
                try c.encode(p_question_index, forKey: .p_question_index)
                try c.encode(p_answer, forKey: .p_answer)
                try c.encode(p_is_correct, forKey: .p_is_correct)
            }
            enum CodingKeys: String, CodingKey { case p_lobby_id, p_question_index, p_answer, p_is_correct }
        }
        try await supabase.rpc("submit_lobby_answer", params: Params(p_lobby_id: lobbyId, p_question_index: questionIndex,
                                                                      p_answer: answer, p_is_correct: isCorrect))
            .execute()
    }

    func advance(lobbyId: UUID, fromIndex: Int) async throws {
        struct Params: Encodable {
            let p_lobby_id: UUID
            let p_from_index: Int
        }
        try await supabase.rpc("advance_lobby", params: Params(p_lobby_id: lobbyId, p_from_index: fromIndex)).execute()
    }

    func leave(lobbyId: UUID) async throws {
        try await supabase.rpc("leave_lobby", params: ["p_lobby_id": lobbyId.uuidString]).execute()
    }

    func invite(lobbyId: UUID, friendId: UUID) async throws {
        struct Params: Encodable {
            let p_lobby_id: UUID
            let p_invited_id: UUID
        }
        try await supabase.rpc("invite_to_lobby", params: Params(p_lobby_id: lobbyId, p_invited_id: friendId)).execute()
    }

    func fetchState(lobbyId: UUID) async throws -> LobbyStateResponse {
        try await supabase.rpc("lobby_state", params: ["p_lobby_id": lobbyId.uuidString]).execute().value
    }

    func fetchInvitations() async throws -> [LobbyInvite] {
        try await supabase.rpc("my_lobby_invites").execute().value
    }

    /// RPC liefert bei „keine Zeile" JSON `null` – `Optional` decodiert das von allein.
    func fetchMyOpenLobby() async throws -> Lobby? {
        try await supabase.rpc("my_open_lobby").execute().value
    }
}
