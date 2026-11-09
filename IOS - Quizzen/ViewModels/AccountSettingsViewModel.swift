//
//  AccountSettingsViewModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 21.07.26.
//

import Foundation
import Supabase
import Combine

@MainActor
class AccountSettingsViewModel: ObservableObject {
    @Published var account: Account?
    @Published var username: String = ""
    @Published var newEmail: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let acc = try await supabase.fetchCurrentAccount()
            account = acc
            username = acc.username
        } catch {
            errorMessage = "Profil konnte nicht geladen werden."
        }
    }

    func saveUsername() async {
        if let problem = UsernameFilter.validationError(for: username) {
            errorMessage = problem
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.updateUsername(username)
            successMessage = "Username aktualisiert."
        } catch {
            errorMessage = error.localizedDescription.contains("username_not_allowed")
                ? "Dieser Benutzername ist nicht erlaubt"
                : "Username konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    func uploadNewAvatar(_ imageData: Data) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let jpeg = ProfileImageCache.jpegForUpload(imageData) ?? imageData
            let newUrl = try await supabase.uploadAvatar(imageData: jpeg)
            account = Account(
                id: account?.id ?? UUID(),
                username: username,
                avatarUrl: newUrl,
                country: account?.country,
                createdAt: account?.createdAt ?? .now
            )
            successMessage = "Profilbild aktualisiert."
        } catch {
            errorMessage = "Profilbild konnte nicht hochgeladen werden: \(error.localizedDescription)"
        }
    }

    func saveEmail() async {
        guard newEmail.contains("@") else {
            errorMessage = "Bitte eine gültige E-Mail eingeben."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.updateEmail(newEmail)
            successMessage = "Bestätigungslink wurde an \(newEmail) gesendet."
            newEmail = ""
        } catch {
            errorMessage = "E-Mail konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }

    func savePassword() async {
        guard newPassword.count >= 6 else {
            errorMessage = "Passwort muss mindestens 6 Zeichen haben."
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwörter stimmen nicht überein."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.updatePassword(newPassword)
            successMessage = "Passwort geändert."
            newPassword = ""
            confirmPassword = ""
        } catch {
            errorMessage = "Passwort konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }
}
