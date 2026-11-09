//
//  AccountSettingsView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 21.07.26.
//

import Foundation
import SwiftUI
import PhotosUI

struct AccountSettingsView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @StateObject private var viewModel = AccountSettingsViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @FocusState private var focused: Field?

    private enum Field { case username, email, password, confirm }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                usernameCard
                emailCard
                passwordCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Accountdaten")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                isUploadingPhoto = true
                defer { isUploadingPhoto = false }
                guard let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                if await viewModel.uploadNewAvatar(data) {
                    userViewModel.profileImageData = ProfileImageCache.jpegForUpload(data) ?? data
                }
                selectedPhoto = nil
            }
        }
        .overlay(alignment: .bottom) { toast }
        .animation(.snappy, value: viewModel.successMessage)
        .alert("Das hat nicht geklappt", isPresented: $viewModel.errorMessage.isPresent()) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(username: viewModel.username.isEmpty ? userViewModel.username : viewModel.username,
                               url: userViewModel.profileImageData == nil ? viewModel.account?.avatarUrl : nil,
                               size: 104,
                               image: userViewModel.profileImageData == nil ? nil : userViewModel.profileImage)
                        .overlay {
                            if isUploadingPhoto {
                                Circle().fill(.black.opacity(0.45))
                                ProgressView().tint(.white)
                            }
                        }
                    Image(systemName: "camera.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.brand, in: Circle())
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 3))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profilbild ändern")

            VStack(spacing: 2) {
                Text(viewModel.account?.username ?? userViewModel.username)
                    .font(.title3.bold())
                if !viewModel.currentEmail.isEmpty {
                    Text(viewModel.currentEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Benutzername

    private var usernameCard: some View {
        SettingsCard(title: "Benutzername", icon: "person.fill", tint: .blue) {
            inputField(icon: "at", text: $viewModel.username, prompt: "Benutzername", field: .username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let problem = viewModel.usernameProblem, viewModel.usernameChanged {
                hint(problem, icon: "exclamationmark.circle.fill", color: .red)
            } else {
                hint("3–20 Zeichen. So sehen dich andere in Bestenlisten und Duellen.", icon: "info.circle", color: .secondary)
            }

            primaryButton("Benutzername speichern", busy: viewModel.isSaving,
                          enabled: viewModel.usernameChanged && viewModel.usernameProblem == nil) {
                focused = nil
                Task {
                    if await viewModel.saveUsername() {
                        userViewModel.username = viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
    }

    // MARK: - E-Mail

    private var emailCard: some View {
        SettingsCard(title: "E-Mail-Adresse", icon: "envelope.fill", tint: .orange) {
            inputField(icon: "envelope", text: $viewModel.newEmail, prompt: "Neue E-Mail-Adresse", field: .email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            hint("Du bekommst einen Bestätigungslink an die neue Adresse. Erst danach gilt sie.",
                 icon: "info.circle", color: .secondary)

            primaryButton("E-Mail ändern", busy: viewModel.isSaving, enabled: viewModel.emailValid) {
                focused = nil
                Task { await viewModel.saveEmail() }
            }
        }
    }

    // MARK: - Passwort

    private var passwordCard: some View {
        SettingsCard(title: "Passwort", icon: "lock.fill", tint: .purple) {
            inputField(icon: "lock", text: $viewModel.newPassword, prompt: "Neues Passwort", field: .password, secure: true)
                .textContentType(.newPassword)

            if !viewModel.newPassword.isEmpty {
                PasswordStrengthBar(strength: viewModel.passwordStrength)
            }

            inputField(icon: "lock.rotation", text: $viewModel.confirmPassword, prompt: "Passwort bestätigen",
                       field: .confirm, secure: true)
                .textContentType(.newPassword)

            if !viewModel.confirmPassword.isEmpty {
                if viewModel.passwordsMatch {
                    hint("Passwörter stimmen überein", icon: "checkmark.circle.fill", color: .green)
                } else {
                    hint("Passwörter stimmen nicht überein", icon: "xmark.circle.fill", color: .red)
                }
            } else {
                hint("Mindestens 6 Zeichen.", icon: "info.circle", color: .secondary)
            }

            primaryButton("Passwort ändern", busy: viewModel.isSaving, enabled: viewModel.passwordValid) {
                focused = nil
                Task { await viewModel.savePassword() }
            }
        }
    }

    // MARK: - Bausteine

    private func inputField(icon: String, text: Binding<String>, prompt: String, field: Field, secure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Group {
                if secure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                }
            }
            .focused($focused, equals: field)
            if !text.wrappedValue.isEmpty && focused == field {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eingabe löschen")
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(focused == field ? Color.brand : .clear, lineWidth: 1.5))
    }

    private func hint(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryButton(_ title: String, busy: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(busy ? 0 : 1)
                if busy { ProgressView().tint(.white) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(enabled ? Color.brand : Color.gray.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || busy)
    }

    @ViewBuilder
    private var toast: some View {
        if let message = viewModel.successMessage {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.green.gradient, in: Capsule())
                .shadow(radius: 8, y: 4)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(2.5))
                    viewModel.successMessage = nil
                }
        }
    }
}

// MARK: - Karte

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title).font(.headline)
            } icon: {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8))
            }
            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Passwortstärke

private struct PasswordStrengthBar: View {
    let strength: AccountSettingsViewModel.PasswordStrength

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < strength.rawValue ? strength.color : Color.gray.opacity(0.25))
                        .frame(height: 5)
                }
            }
            Text(strength.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(strength.color)
                .frame(width: 56, alignment: .trailing)
        }
        .animation(.snappy, value: strength)
    }
}
