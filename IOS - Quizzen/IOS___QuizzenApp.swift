//
//  IOS___QuizzenApp.swift
//  IOS - Quizzen
//

import SwiftUI

@main
struct IOS___Quizzen: App {
    @StateObject private var statsManager = StatsManager()
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(statsManager)
                .environmentObject(userViewModel)
                .environmentObject(authViewModel)
                .environmentObject(friendsViewModel)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Streak kann über Nacht abgelaufen sein, während die App im
                // Hintergrund lag – ohne Neustart würde sonst der veraltete
                // Wert weiter angezeigt.
                statsManager.globalManager.updateStreakIfNeeded()
            case .background:
                StreakReminder.reschedule(stats: statsManager.globalManager.stats)
            default:
                break
            }
        }
    }
}
