//
//  AppRouter.swift
//  IOS - Quizzen
//
//  Tab-Auswahl und Sprünge zwischen Tabs (z. B. „Freund herausfordern“
//  aus einem Profil heraus öffnet den Duell-Tab mit Einladung).
//

import SwiftUI
import Combine

enum AppTab: Hashable {
    case home, duel, leaderboard, friends, search
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    /// Freund, der zum Duell eingeladen werden soll (wird vom Duell-Tab abgeholt)
    @Published var duelInvite: Account?
    /// Bestenliste, die beim Wechsel in den Tab geöffnet werden soll
    @Published var requestedBoard: LeaderboardBoard?

    func showLeaderboard(_ board: LeaderboardBoard) {
        requestedBoard = board
        selectedTab = .leaderboard
    }

    func challenge(_ friend: Account) {
        duelInvite = friend
        selectedTab = .duel
    }
}
