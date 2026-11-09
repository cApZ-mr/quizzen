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

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(statsManager)
                .environmentObject(userViewModel)
                .environmentObject(authViewModel)
                .environmentObject(friendsViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
