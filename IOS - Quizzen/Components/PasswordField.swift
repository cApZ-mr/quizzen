//
//  PasswordField.swift
//  IOS - Quizzen
//
//  Passwort-Eingabe mit Augen-Icon zum Ein-/Ausblenden. SecureField und
//  TextField liegen übereinander und teilen sich einen Fokus, damit die
//  Tastatur beim Umschalten nicht verschwindet – vorher wurde beim
//  Einblenden nur das SecureField ausgeblendet, ohne den Klartext
//  irgendwo anzuzeigen.
//

import SwiftUI

struct PasswordField: View {
    var placeholder: String = String(localized: "Passwort")
    @Binding var text: String
    var textContentType: UITextContentType?

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)

            ZStack(alignment: .leading) {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                    .opacity(isRevealed ? 0 : 1)
                    .allowsHitTesting(!isRevealed)
                    .focused($isFocused)
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.4)))
                    .opacity(isRevealed ? 1 : 0)
                    .allowsHitTesting(isRevealed)
                    .focused($isFocused)
            }
            .foregroundColor(.white)
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .padding()
            }
            .accessibilityLabel(isRevealed ? String(localized: "Passwort verbergen") : String(localized: "Passwort anzeigen"))
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }
}
