//
//  AccountSettingsViewModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 21.07.26.
//

import Foundation
import SwiftUI
import Supabase
import Combine

@MainActor
class AccountSettingsViewModel: ObservableObject {
    @Published var account: Account?
    @Published var currentEmail: String = ""
    @Published var username: String = ""
    @Published var newEmail: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Abgeleitete Zustände für die Oberfläche

    var trimmedUsername: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }
    var usernameChanged: Bool { !trimmedUsername.isEmpty && trimmedUsername != account?.username }
    var usernameProblem: String? { UsernameFilter.validationError(for: username) }

    var emailValid: Bool {
        let value = newEmail.trimmingCharacters(in: .whitespaces)
        return value.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
            && value.lowercased() != currentEmail.lowercased()
    }

    var passwordsMatch: Bool { !newPassword.isEmpty && newPassword == confirmPassword }
    var passwordValid: Bool { newPassword.count >= 6 && passwordsMatch }

    enum PasswordStrength: Int {
        case weak = 1, medium, strong

        var label: String {
            switch self {
            case .weak: "Schwach"
            case .medium: "Mittel"
            case .strong: "Stark"
            }
        }

        var color: Color {
            switch self {
            case .weak: .red
            case .medium: .orange
            case .strong: .green
            }
        }
    }

    var passwordStrength: PasswordStrength {
        let p = newPassword
        var score = 0
        if p.count >= 8 { score += 1 }
        if p.count >= 12 { score += 1 }
        if p.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if p.rangeOfCharacter(from: .uppercaseLetters) != nil && p.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if p.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil { score += 1 }
        if p.count < 6 || score <= 1 { return .weak }
        return score <= 3 ? .medium : .strong
    }

    // MARK: - Laden & Speichern

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let acc = try await supabase.fetchCurrentAccount()
            account = acc
            username = acc.username
            currentEmail = (try? await supabase.auth.session.user.email) ?? ""
        } catch {
            errorMessage = "Profil konnte nicht geladen werden."
        }
    }

    @discardableResult
    func saveUsername() async -> Bool {
        if let problem = usernameProblem {
            errorMessage = problem
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.updateUsername(trimmedUsername)
            if let account {
                self.account = Account(id: account.id, username: trimmedUsername, avatarUrl: account.avatarUrl,
                                       country: account.country, createdAt: account.createdAt)
            }
            username = trimmedUsername
            successMessage = "Benutzername gespeichert"
            return true
        } catch {
            let text = error.localizedDescription
            if text.contains("username_not_allowed") {
                errorMessage = "Dieser Benutzername ist nicht erlaubt."
            } else if text.localizedCaseInsensitiveContains("duplicate") || text.contains("23505") {
                errorMessage = "Dieser Benutzername ist schon vergeben."
            } else {
                errorMessage = "Benutzername konnte nicht gespeichert werden. Bitte versuch es erneut."
            }
            return false
        }
    }

    @discardableResult
    func uploadNewAvatar(_ imageData: Data) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let jpeg = ProfileImageCache.jpegForUpload(imageData) ?? imageData
            let newUrl = try await supabase.uploadAvatar(imageData: jpeg)
            account = Account(
                id: account?.id ?? UUID(),
                username: account?.username ?? username,
                avatarUrl: newUrl,
                country: account?.country,
                createdAt: account?.createdAt ?? .now
            )
            successMessage = "Profilbild aktualisiert"
            return true
        } catch {
            errorMessage = "Profilbild konnte nicht hochgeladen werden. Bitte versuch es erneut."
            return false
        }
    }

    func saveEmail() async {
        let value = newEmail.trimmingCharacters(in: .whitespaces)
        guard emailValid else {
            errorMessage = "Bitte gib eine gültige, neue E-Mail-Adresse ein."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.updateEmail(value)
            successMessage = "Bestätigungslink an \(value) gesendet"
            newEmail = ""
        } catch {
            errorMessage = "E-Mail konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }

    func savePassword() async {
        guard newPassword.count >= 6 else {
            errorMessage = "Das Passwort muss mindestens 6 Zeichen haben."
            return
        }
        guard passwordsMatch else {
            errorMessage = "Die Passwörter stimmen nicht überein."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.updatePassword(newPassword)
            successMessage = "Passwort geändert"
            newPassword = ""
            confirmPassword = ""
        } catch {
            errorMessage = "Passwort konnte nicht geändert werden: \(error.localizedDescription)"
        }
    }
}
