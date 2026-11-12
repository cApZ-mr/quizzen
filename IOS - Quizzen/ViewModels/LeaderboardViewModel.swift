//
//  LeaderboardViewModel.swift
//  IOS - Quizzen
//

import Foundation
import Combine
import Supabase

@MainActor
final class LeaderboardViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    @Published var board: LeaderboardBoard = .stat(.xp)
    @Published var scope: LeaderboardScope = .global
    @Published private(set) var entries: [LeaderboardEntry] = []
    @Published private(set) var myRank: Int?
    @Published private(set) var myUserId: UUID?
    @Published private(set) var state: LoadState = .idle

    /// Wird nach jedem Laden befüllt, damit veraltete Antworten
    /// (schneller Wechsel zwischen Bestenlisten) verworfen werden.
    private var requestToken = UUID()

    func load(myStats: GlobalStats, friendIds: [UUID], countryCode: String) async {
        let token = UUID()
        requestToken = token
        state = .loading

        if myUserId == nil {
            myUserId = try? await supabase.auth.session.user.id
        }

        var filter = LeaderboardFilter()
        switch scope {
        case .global:
            break
        case .friends:
            filter.userIds = friendIds + [myUserId].compactMap { $0 }
        case .country:
            filter.countryCode = countryCode.isEmpty ? nil : countryCode
        }

        do {
            let result: [LeaderboardEntry]
            var rank: Int?

            switch board {
            case .stat(let metric):
                async let list = supabase.fetchLeaderboard(metric: metric, filter: filter)
                async let ownRank = try? supabase.fetchMyRank(metric: metric, myValue: metric.value(in: myStats), filter: filter)
                result = try await list
                rank = await ownRank ?? nil
            case .daily:
                result = try await supabase.fetchQuizCategoryLeaderboard(quizIds: [DailyChallenge.quizId()], filter: filter)
                rank = result.first { $0.id == myUserId }?.rank
            case .quiz(let quizId, _, _):
                // Gemeisterte Fragen – unabhängig von Rundenlänge und Wiederholungen
                result = try await supabase.fetchQuizMastery(quizId: quizId, filter: filter)
                rank = result.first { $0.id == myUserId }?.rank
            }

            guard token == requestToken else { return }
            entries = result
            myRank = rank ?? result.first { $0.id == myUserId }?.rank
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard token == requestToken else { return }
            log.error("Bestenliste konnte nicht geladen werden: \(error.localizedDescription)")
            entries = []
            myRank = nil
            if case .daily = board {
                state = .failed(String(localized: "Die Tages-Bestenliste ist noch nicht freigeschaltet (Server-Update 002 ausstehend)."))
            } else if case .quiz = board {
                state = .failed(String(localized: "Quiz-Bestenlisten sind noch nicht freigeschaltet (Server-Update 006 ausstehend)."))
            } else if case .stat(.xp) = board, "\(error)".contains("xp") {
                state = .failed(String(localized: "Die XP-Bestenliste ist noch nicht freigeschaltet (Server-Update 011 ausstehend)."))
            } else {
                state = .failed(String(localized: "Bestenliste konnte nicht geladen werden. Prüfe deine Internetverbindung."))
            }
        }
    }

    func isMe(_ entry: LeaderboardEntry) -> Bool {
        entry.id == myUserId
    }
}
