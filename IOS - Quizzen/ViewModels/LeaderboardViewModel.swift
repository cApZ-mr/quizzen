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

    @Published var board: LeaderboardBoard = .stat(.correctAnswers)
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
            case .quiz(let quizId, _, _):
                // Neue Runden + Versuche der früheren Einzel-Quizze
                let quizIds = [quizId] + (QuizCatalog.definition(for: quizId)?.legacyQuizIds ?? [])
                result = try await supabase.fetchQuizCategoryLeaderboard(quizIds: quizIds, filter: filter)
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
            if case .quiz = board {
                state = .failed("Quiz-Bestenlisten sind noch nicht freigeschaltet (Server-Update 002 ausstehend).")
            } else {
                state = .failed("Bestenliste konnte nicht geladen werden. Prüfe deine Internetverbindung.")
            }
        }
    }

    func isMe(_ entry: LeaderboardEntry) -> Bool {
        entry.id == myUserId
    }
}
