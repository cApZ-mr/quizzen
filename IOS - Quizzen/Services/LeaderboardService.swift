//
//  LeaderboardService.swift
//  IOS - Quizzen
//
//  Server-Abfragen für die Bestenliste.
//  - Kennzahlen (Richtige, Runden, Streaks): direkt aus user_stats
//  - Quiz-Kategorien: RPC leaderboard_quiz_scores (Migration 002)
//

import Foundation
import Supabase

nonisolated private struct LeaderboardAccountRow: Decodable {
    let id: UUID
    let username: String
    let avatar_url: String?
    let country: String?
    let created_at: Date
}

nonisolated private struct LeaderboardStatRow: Decodable {
    let user_id: UUID
    let value: Double
    let accounts: LeaderboardAccountRow
}

nonisolated private struct LeaderboardRPCRow: Decodable {
    let user_id: UUID
    let username: String
    let avatar_url: String?
    let country: String?
    let created_at: Date
    let value: Double
}

nonisolated private struct LeaderboardRPCParams: Encodable {
    let quiz_ids: [String]
    let user_ids: [String]?
    let country_code: String?
    let max_rows: Int
}

/// Filter, der für alle Bestenlisten gleich angewendet wird.
nonisolated struct LeaderboardFilter: Sendable {
    var userIds: [UUID]? = nil      // nur diese Nutzer (Freunde + ich)
    var countryCode: String? = nil  // nur dieses Land
}

extension SupabaseClient {

    static let leaderboardLimit = 50

    /// Top-Liste für eine Kennzahl aus user_stats (nur Nutzer mit Wert > 0).
    func fetchLeaderboard(metric: LeaderboardMetric, filter: LeaderboardFilter) async throws -> [LeaderboardEntry] {
        let column = metric.rawValue
        var query = from("user_stats")
            .select("user_id, value:\(column), accounts!inner(id, username, avatar_url, country, created_at)")
            .gt(column, value: 0)

        if let ids = filter.userIds {
            query = query.in("user_id", values: ids.map(\.uuidString))
        }
        if let country = filter.countryCode {
            query = query.eq("accounts.country", value: country)
        }

        let rows: [LeaderboardStatRow] = try await query
            .order(column, ascending: false)
            .limit(Self.leaderboardLimit)
            .execute()
            .value

        return LeaderboardEntry.ranked(rows.map { row in
            (Account(id: row.accounts.id, username: row.accounts.username, avatarUrl: row.accounts.avatar_url,
                     country: row.accounts.country, createdAt: row.accounts.created_at),
             Int(row.value))
        })
    }

    /// Eigener Platz für eine Kennzahl: Anzahl Nutzer mit höherem Wert + 1.
    func fetchMyRank(metric: LeaderboardMetric, myValue: Int, filter: LeaderboardFilter) async throws -> Int? {
        guard myValue > 0 else { return nil }
        let column = metric.rawValue
        var query = from("user_stats")
            .select("user_id, accounts!inner(country)", head: true, count: .exact)
            .gt(column, value: myValue)

        if let ids = filter.userIds {
            query = query.in("user_id", values: ids.map(\.uuidString))
        }
        if let country = filter.countryCode {
            query = query.eq("accounts.country", value: country)
        }

        let response = try await query.execute()
        return (response.count ?? 0) + 1
    }

    /// Top-Liste für eine Quiz-Kategorie: Summe der Bestwerte pro Quiz.
    func fetchQuizCategoryLeaderboard(quizIds: [String], filter: LeaderboardFilter) async throws -> [LeaderboardEntry] {
        let params = LeaderboardRPCParams(
            quiz_ids: quizIds,
            user_ids: filter.userIds?.map(\.uuidString),
            country_code: filter.countryCode,
            max_rows: Self.leaderboardLimit
        )
        let rows: [LeaderboardRPCRow] = try await rpc("leaderboard_quiz_scores", params: params)
            .execute()
            .value

        return LeaderboardEntry.ranked(rows.map { row in
            (Account(id: row.user_id, username: row.username, avatarUrl: row.avatar_url,
                     country: row.country, createdAt: row.created_at),
             Int(row.value))
        })
    }
}
