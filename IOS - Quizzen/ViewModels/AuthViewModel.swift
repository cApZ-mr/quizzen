//
//  AuthViewModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 06.07.26.
//

import Foundation
import Combine
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true

    init() {
        Task {
            await checkSession()
            await listenToAuthChanges()
        }
    }

    // Beim App-Start prüfen, ob schon eine gespeicherte Session existiert
    func checkSession() async {
        do {
            _ = try await supabase.auth.session
            isLoggedIn = true
        } catch {
            isLoggedIn = false
        }
        isLoading = false
    }

    // Reagiert automatisch auf Login/Logout, z.B. auch nach signUp
    func listenToAuthChanges() async {
        for await state in supabase.auth.authStateChanges {
            switch state.event {
            case .signedIn:
                isLoggedIn = true
            case .signedOut:
                isLoggedIn = false
            default:
                break
            }
        }
    }

    func logout() async throws {
        try await supabase.auth.signOut()
    }
}
