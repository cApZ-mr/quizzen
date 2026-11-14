//
//  LobbyJoinForm.swift
//  IOS - Quizzen
//
//  Code-Eingabe zum Beitreten einer Lobby.
//

import SwiftUI

struct LobbyJoinForm: View {
    @ObservedObject var session: LobbySession

    @State private var code = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "number")
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.purple.gradient, in: Circle())
                Text("Code eingeben")
                    .font(.title2.bold())
                Text("Gib den 6-stelligen Code ein, den dir jemand geschickt hat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            codeBoxes

            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await session.joinLobby(code: code) }
            } label: {
                Group {
                    if session.isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text("Beitreten")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(code.count == 6 ? AnyShapeStyle(Color.brand) : AnyShapeStyle(Color.gray.opacity(0.4)),
                            in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(code.count != 6 || session.isBusy)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { isFocused = true }
    }

    /// Sechs einzelne Kästchen über einem unsichtbaren Textfeld
    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    code = String(digits.prefix(6))
                    session.errorMessage = nil
                    if code.count == 6 && !session.isBusy {
                        Task { await session.joinLobby(code: code) }
                    }
                }

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let digit = index < code.count ? String(Array(code)[index]) : ""
                    let isActive = index == code.count && isFocused
                    Text(digit)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .frame(width: 46, height: 58)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? Color.brandLight : .clear, lineWidth: 2))
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .accessibilityElement()
        .accessibilityLabel("Code, \(code.count) von 6 Ziffern")
    }
}
