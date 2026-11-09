//
//  SupabaseManager.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 06.07.26.
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://kaqjulzcmlxujjzwpfsk.supabase.co")!,
    supabaseKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImthcWp1bHpjbWx4dWpqendwZnNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MTY5MjcsImV4cCI6MjA5OTE5MjkyN30.f_9gAZWhxcBgNBnKGrxwtca2AKfORaufy_ENMXX2TrM"
)

// MARK: - Sync-Datenmodelle
nonisolated private struct QuizAttemptRecord: Encodable {
    let user_id: String
    let quiz_id: String
    let score: Int
    let max_score: Int
}

nonisolated private struct UserStatsRecord: Codable {
    let user_id: String
    var total_answers: Int
    var correct_answers: Int
    var false_answers: Int
    var quizzes_played: Int
    var current_streak: Int
    var best_streak: Int
    var play_time: Double
    // Neu (Migration supabase/migrations/001_*.sql). Optional, damit alte
    // Zeilen dekodierbar bleiben; nil-Werte werden beim Encoden weggelassen.
    var last_played_date: Date?
    var install_date: Date?
}

nonisolated private struct FriendshipRow: Decodable {
    let requester_id: UUID
    let addressee_id: UUID
}

nonisolated private struct IncomingRequestRow: Decodable {
    let requester_id: UUID
}

nonisolated private struct OutgoingFriendshipRow: Decodable {
    let addressee_id: UUID
}

/// Fortschritt eines Quiz auf dem Server (Tabelle user_quiz_progress)
nonisolated struct QuizProgressRecord: Codable {
    var user_id: String = ""
    let quiz_key: String
    let quiz_id: String
    let rounds_played: Int
    let answered_ids: [String]
    let correct_ids: [String]
    let false_ids: [String]

    init(quizKey: String, quizId: String, stats: CategoryStats) {
        quiz_key = quizKey
        quiz_id = quizId
        rounds_played = stats.roundsPlayed
        answered_ids = Array(stats.answeredIDs)
        correct_ids = Array(stats.correctIDs.intersection(stats.answeredIDs))
        false_ids = Array(stats.falseIDs.intersection(stats.answeredIDs))
    }

    var stats: CategoryStats {
        CategoryStats(roundsPlayed: rounds_played, answeredIDs: Set(answered_ids),
                      correctIDs: Set(correct_ids), falseIDs: Set(false_ids))
    }
}

struct FriendWithSince: Identifiable, Hashable {
    let account: AccountWithStats
    let friendsSince: Date

    var id: UUID { account.id }
}

struct FriendshipStatusEntry {
    let friendshipId: UUID
    let status: FriendshipStatus
    let iAmRequester: Bool
}

// MARK: - Stats-Sync

extension SupabaseClient {

    /// Speichert einen einzelnen abgeschlossenen Quiz-Versuch (Historie).
    /// Wird nur aufgerufen, nicht abgewartet - Fehler landen im Log,
    /// blockieren aber nie die UI.
    func saveQuizAttempt(quizId: String, score: Int, maxScore: Int) async {
        guard let userId = try? await auth.session.user.id else {
            log.notice("Kein eingeloggter Nutzer - Quiz-Versuch wird nicht gespeichert.")
            return
        }

        let record = QuizAttemptRecord(
            user_id: userId.uuidString,
            quiz_id: quizId,
            score: score,
            max_score: maxScore
        )

        do {
            try await from("quiz_attempts").insert(record).execute()
        } catch {
            log.error("Fehler beim Speichern des Quiz-Versuchs: \(error.localizedDescription)")
        }
    }

    /// Schreibt die aktuellen aggregierten Stats in user_stats (upsert:
    /// legt die Zeile beim ersten Mal an, aktualisiert sie danach).
    func syncUserStats(_ stats: GlobalStats) async {
        guard let userId = try? await auth.session.user.id else {
            log.notice("Kein eingeloggter Nutzer - Stats werden nicht synchronisiert.")
            return
        }

        let record = UserStatsRecord(
            user_id: userId.uuidString,
            total_answers: stats.totalAnswers,
            correct_answers: stats.correctAnswers,
            false_answers: stats.falseAnswers,
            quizzes_played: stats.quizzesPlayed,
            current_streak: stats.currentStreak,
            best_streak: stats.bestStreak,
            play_time: stats.playTime,
            last_played_date: stats.lastPlayedDate,
            install_date: stats.installDate
        )

        do {
            try await from("user_stats").upsert(record).execute()
        } catch {
            // Fallback, falls die Migration (neue Spalten) noch nicht eingespielt ist.
            var legacy = record
            legacy.last_played_date = nil
            legacy.install_date = nil
            do {
                try await from("user_stats").upsert(legacy).execute()
                log.notice("user_stats ohne Streak-Datum synchronisiert – Migration 001 fehlt?")
            } catch {
                log.error("Statistiken konnten nicht synchronisiert werden: \(error.localizedDescription)")
            }
        }
    }

    /// Lädt die serverseitigen Stats des eingeloggten Nutzers, z.B. beim
    /// Login, um GlobalStats geräteübergreifend zu synchronisieren.
    /// Gibt nil zurück, falls kein Nutzer eingeloggt ist oder noch keine
    /// Zeile existiert (z.B. erster Login auf neuem Gerät).
    func loadUserStats() async -> GlobalStats? {
        guard let userId = try? await auth.session.user.id else { return nil }

        do {
            let record: UserStatsRecord = try await from("user_stats")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value

            var stats = GlobalStats()
            stats.totalAnswers = record.total_answers
            stats.correctAnswers = record.correct_answers
            stats.falseAnswers = record.false_answers
            stats.quizzesPlayed = record.quizzes_played
            stats.currentStreak = record.current_streak
            stats.bestStreak = record.best_streak
            stats.playTime = record.play_time
            stats.lastPlayedDate = record.last_played_date
            if let installDate = record.install_date { stats.installDate = installDate }
            return stats
        } catch {
            log.info("Keine Server-Stats gefunden (evtl. erster Login): \(error.localizedDescription)")
            return nil
        }
    }
    
    
    // MARK: - Quiz-Fortschritt

    /// Lädt den Fortschritt aller Quizze (nil bei Fehler, z. B. Migration 006 fehlt)
    func loadQuizProgress() async -> [String: CategoryStats]? {
        guard let userId = try? await auth.session.user.id else { return nil }
        do {
            let rows: [QuizProgressRecord] = try await from("user_quiz_progress")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            return Dictionary(rows.map { ($0.quiz_key, $0.stats) }, uniquingKeysWith: { first, _ in first })
        } catch {
            log.notice("Quiz-Fortschritt konnte nicht geladen werden: \(error.localizedDescription)")
            return nil
        }
    }

    func syncQuizProgress(_ records: [QuizProgressRecord]) async {
        guard !records.isEmpty, let userId = try? await auth.session.user.id else { return }
        let rows = records.map { record -> QuizProgressRecord in
            var row = record
            row.user_id = userId.uuidString
            return row
        }
        do {
            try await from("user_quiz_progress").upsert(rows).execute()
        } catch {
            log.notice("Quiz-Fortschritt konnte nicht synchronisiert werden: \(error.localizedDescription)")
        }
    }

    // Lädt alle bestätigten Freunde
    func fetchFriends() async throws -> [FriendWithSince] {
        guard let myId = try? await auth.session.user.id else { return [] }

        struct FriendshipRowWithDate: Decodable {
            let requester_id: UUID
            let addressee_id: UUID
            let updated_at: Date
        }

        let rows: [FriendshipRowWithDate] = try await from("friendships")
            .select("requester_id, addressee_id, updated_at")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(myId.uuidString),addressee_id.eq.\(myId.uuidString)")
            .execute()
            .value

        if rows.isEmpty { return [] }

        // Map: Freund-ID -> Datum der Annahme
        var sinceByFriendId: [UUID: Date] = [:]
        for row in rows {
            let friendId = row.requester_id == myId ? row.addressee_id : row.requester_id
            sinceByFriendId[friendId] = row.updated_at
        }

        let accounts: [AccountWithStats] = try await from("accounts")
            .select("*, user_stats(*)")
            .in("id", values: Array(sinceByFriendId.keys).map { $0.uuidString })
            .execute()
            .value

        return accounts.compactMap { account in
            guard let since = sinceByFriendId[account.id] else { return nil }
            return FriendWithSince(account: account, friendsSince: since)
        }
    }
    
    // Anzahl bestätigter Freunde einer beliebigen Person (z. B. für PublicProfileView)
    func fetchFriendCount(for userId: UUID) async throws -> Int {
        // Bevorzugt die RPC aus 009 (RLS zeigt sonst nur eigene Freundschaften)
        if let count: Int = try? await rpc("friend_count", params: ["p_user": userId.uuidString]).execute().value {
            return count
        }
        let rows: [FriendshipRow] = try await from("friendships")
            .select("requester_id, addressee_id")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userId.uuidString),addressee_id.eq.\(userId.uuidString)")
            .execute()
            .value

        return rows.count
    }
    
    func fetchAllFriendshipStatuses() async throws -> [UUID: FriendshipStatusEntry] {
        guard let myId = try? await auth.session.user.id else { return [:] }

        let rows: [Friendship] = try await from("friendships")
            .select()
            .or("requester_id.eq.\(myId.uuidString),addressee_id.eq.\(myId.uuidString)")
            .execute()
            .value

        var map: [UUID: FriendshipStatusEntry] = [:]
        for row in rows {
            let otherId = row.requesterId == myId ? row.addresseeId : row.requesterId
            map[otherId] = FriendshipStatusEntry(
                friendshipId: row.id,
                status: row.status,
                iAmRequester: row.requesterId == myId
            )
        }
        return map
    }
    
    func fetchIncomingRequests() async throws -> [Account] {
        guard let myId = try? await auth.session.user.id else { return [] }
        
        let rows: [IncomingRequestRow] = try await from("friendships")
            .select("requester_id") // Hier selektierst du nur requester_id
            .eq("addressee_id", value: myId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
            
        let requesterIds = rows.map { $0.requester_id }
        
        if requesterIds.isEmpty { return [] }
        
        return try await from("accounts")
            .select()
            .in("id", values: requesterIds.map { $0.uuidString })
            .execute()
            .value
    }
    
    func fetchOutgoingRequests() async throws -> [Account] {
        guard let myId = try? await auth.session.user.id else { return [] }

        let rows: [OutgoingFriendshipRow] = try await from("friendships")
            .select("addressee_id")
            .eq("requester_id", value: myId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value

        let addresseeIds = rows.map { $0.addressee_id }
        if addresseeIds.isEmpty { return [] }

        return try await from("accounts")
            .select()
            .in("id", values: addresseeIds.map { $0.uuidString })
            .execute()
            .value
    }
    
    // Stats einer bestimmten Person laden (für PublicProfileView)
    func fetchStats(for userId: UUID) async throws -> AccountStats? {
        let rows: [AccountStats] = try await from("user_stats")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.first
    }

    // Bestehende Freundschaft/Anfrage zwischen mir und jemand anderem finden (egal in welche Richtung)
    func fetchFriendship(with otherId: UUID) async throws -> Friendship? {
        guard let myId = try? await auth.session.user.id else { return nil }
        let rows: [Friendship] = try await from("friendships")
            .select()
            .or("and(requester_id.eq.\(myId.uuidString),addressee_id.eq.\(otherId.uuidString)),and(requester_id.eq.\(otherId.uuidString),addressee_id.eq.\(myId.uuidString))")
            .execute()
            .value
        return rows.first
    }

    func sendFriendRequest(to otherId: UUID) async throws {
        guard let myId = try? await auth.session.user.id else { return }
        struct NewFriendship: Encodable {
            let requester_id: String
            let addressee_id: String
            let status: String
        }
        try await from("friendships")
            .insert(NewFriendship(requester_id: myId.uuidString, addressee_id: otherId.uuidString, status: "pending"))
            .execute()
    }

    func acceptFriendRequest(id: UUID) async throws {
        try await from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // Deckt ab: Anfrage ablehnen, Anfrage zurückziehen, Freundschaft beenden
    func removeFriendship(id: UUID) async throws {
        try await from("friendships")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Sucht Accounts nach Username (case-insensitive), schließt einen selbst aus
    func searchAccounts(query: String) async throws -> [AccountWithStats] {
        guard !query.isEmpty else { return [] }
        guard let myId = try? await auth.session.user.id else { return [] }

        let results: [AccountWithStats] = try await from("accounts")
            .select("*, user_stats(*)")
            .ilike("username", pattern: "%\(query)%")
            .neq("id", value: myId.uuidString)
            .limit(30)
            .execute()
            .value
        return results.filter { !BlockList.shared.isHidden($0.id) }
    }
    
    func fetchSuggestedAccounts(count: Int = 5) async throws -> [AccountWithStats] {
        let ids: [UUID] = try await rpc("suggested_accounts", params: ["count": count])
            .execute()
            .value

        if ids.isEmpty { return [] }

        let accounts: [AccountWithStats] = try await from("accounts")
            .select("*, user_stats(*)")
            .in("id", values: ids.map { $0.uuidString })
            .execute()
            .value

        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        return accounts
            .filter { !BlockList.shared.isHidden($0.id) }
            .sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }
    
    
    // MARK: - Account-Settings

    func fetchCurrentAccount() async throws -> Account {
        guard let myId = try? await auth.session.user.id else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Nicht eingeloggt"])
        }
        return try await from("accounts")
            .select()
            .eq("id", value: myId.uuidString)
            .single()
            .execute()
            .value
    }

    func updateUsername(_ newUsername: String) async throws {
        guard let myId = try? await auth.session.user.id else { return }
        struct UsernameUpdate: Encodable { let username: String }
        try await from("accounts")
            .update(UsernameUpdate(username: newUsername))
            .eq("id", value: myId.uuidString)
            .execute()
    }

    /// Lädt ein neues Profilbild hoch (überschreibt das alte unter demselben Pfad)
    /// und aktualisiert avatar_url in accounts. Gibt die neue öffentliche URL zurück.
    func uploadAvatar(imageData: Data) async throws -> String {
        guard let myId = try? await auth.session.user.id else {
            throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Nicht eingeloggt"])
        }
        let path = "\(myId.uuidString)/avatar.jpg"   // <- Ordner-Präfix hinzugefügt

        try await storage.from("avatars").upload(
            path,
            data: imageData,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        )

        // Cache-Buster: gleicher Pfad wird überschrieben, sonst zeigen
        // AsyncImage/CDN bis zu 1 h lang noch das alte Bild.
        let baseURL = try storage.from("avatars").getPublicURL(path: path)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))]
        let publicURL = components?.url ?? baseURL

        struct AvatarUpdate: Encodable { let avatar_url: String }
        try await from("accounts")
            .update(AvatarUpdate(avatar_url: publicURL.absoluteString))
            .eq("id", value: myId.uuidString)
            .execute()

        return publicURL.absoluteString
    }

    func updateEmail(_ newEmail: String) async throws {
        try await auth.update(user: UserAttributes(email: newEmail))
    }

    func updatePassword(_ newPassword: String) async throws {
        try await auth.update(user: UserAttributes(password: newPassword))
    }
    

    func fetchSocialProfile(for userId: UUID) async throws -> SocialProfile? {
        let rows: [SocialProfile] = try await from("social_profiles")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.first
    }

    func upsertMySocialProfile(bannerId: String?, selectedBadges: [String]) async throws {
        guard let myId = try? await auth.session.user.id else { return }
        let record = SocialProfile(userId: myId, bannerId: bannerId, selectedBadges: selectedBadges)
        try await from("social_profiles")
            .upsert(record)
            .execute()
    }
}
