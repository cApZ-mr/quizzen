//
//  LoginView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 06.07.26.
//

import Foundation
import SwiftUI
import Supabase

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showLogin: Bool

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var validationMessage: String?
    @State private var isLoggingIn = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Willkommen zurück")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                        Text("Melde dich mit deinem Account an.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            TextField("", text: $email, prompt: Text("E-Mail").foregroundColor(.white.opacity(0.4)))
                                .foregroundColor(.white)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)

                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            SecureField("", text: $password, prompt: Text("Passwort").foregroundColor(.white.opacity(0.4)))
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        Task { await login() }
                    } label: {
                        Group {
                            if isLoggingIn {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Einloggen")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(28)
                    }
                    .disabled(isLoggingIn)

                    Button {
                        dismiss()
                    } label: {
                        Text("Noch keinen Account? Registrieren")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .top) {
            if let validationMessage {
                validationBanner(validationMessage)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Login-Logik
    private func login() async {
        guard isValidEmail(email) else {
            showValidationMessage(String(localized: "Bitte gib eine gültige E-Mail-Adresse ein"))
            return
        }
        guard !password.isEmpty else {
            showValidationMessage(String(localized: "Bitte gib dein Passwort ein"))
            return
        }

        isLoggingIn = true
        do {
            try await supabase.auth.signIn(email: email, password: password)
            // isLoggedIn wird automatisch über den Auth-State-Listener aktualisiert
        } catch {
            showValidationMessage(String(localized: "E-Mail oder Passwort falsch"))
        }
        isLoggingIn = false
    }

    // MARK: - Validierungs-Banner (identisch zu ProfileSetupView)
    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(.subheadline, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }
    private func showValidationMessage(_ message: String) {
        withAnimation(.easeOut(duration: 0.25)) {
            validationMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeIn(duration: 0.25)) {
                validationMessage = nil
            }
        }
    }
    private func isValidEmail(_ email: String) -> Bool {
        guard let atIndex = email.firstIndex(of: "@") else { return false }
        let afterAt = email[email.index(after: atIndex)...]
        return !afterAt.isEmpty && afterAt.contains(".")
    }
}

// MARK: - Preview
#Preview {
    LoginView(showLogin: .constant(true))
}
