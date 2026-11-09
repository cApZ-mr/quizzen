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
    @StateObject private var viewModel = AccountSettingsViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        List {
            // MARK: Profilbild + Username
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        let avatarURL = URL(string: viewModel.account?.avatarUrl ?? "")
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                AsyncImage(url: avatarURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 88, height: 88)
                                .clipShape(Circle())

                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(Circle())
                            }
                        }
                        Text("Profilbild ändern")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)

                HStack {
                    Text("Username")
                    Spacer()
                    TextField("Username", text: $viewModel.username)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await viewModel.saveUsername() }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Username speichern")
                    }
                }
                .disabled(viewModel.isSaving)
            }

            // MARK: E-Mail
            Section {
                TextField("Neue E-Mail-Adresse", text: $viewModel.newEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                Button("E-Mail ändern") {
                    Task { await viewModel.saveEmail() }
                }
                .disabled(viewModel.isSaving || viewModel.newEmail.isEmpty)
            } header: {
                Text("E-Mail")
            } footer: {
                Text("Du erhältst einen Bestätigungslink an die neue Adresse. Die Änderung wird erst nach der Bestätigung wirksam.")
            }

            // MARK: Passwort
            Section {
                SecureField("Neues Passwort", text: $viewModel.newPassword)
                SecureField("Passwort bestätigen", text: $viewModel.confirmPassword)

                Button("Passwort ändern") {
                    Task { await viewModel.savePassword() }
                }
                .disabled(viewModel.isSaving || viewModel.newPassword.isEmpty)
            } header: {
                Text("Passwort")
            } footer: {
                Text("Mindestens 6 Zeichen.")
            }
        }
        .navigationTitle("Account bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                await viewModel.uploadNewAvatar(data)
            }
        }
        .alert("Fehler", isPresented: $viewModel.errorMessage.isPresent()) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Erfolg", isPresented: $viewModel.successMessage.isPresent()) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }
}
