//
//  WelcomeView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 06.07.26.
//

import Foundation
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var introTextVisible = false
    @State private var buttonsVisible = false

    @State private var goToSignUp = false
    @State private var goToLogin = false

    var body: some View {
        ZStack {
            SetupBackground(imageName: "AppIconDark")

            VStack(spacing: 0) {
                Spacer()
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("Willkommen")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Trete an, sammle Punkte und\nvergleiche dich mit der Welt.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 150)
                .offset(y: introTextVisible ? 0 : 40)
                .opacity(introTextVisible ? 1 : 0)

                VStack(spacing: 16) {
                    Button {
                        goToSignUp = true
                    } label: {
                        Text("Account erstellen")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(28)
                    }

                    Button {
                        goToLogin = true
                    } label: {
                        Text("Einloggen")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(28)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(buttonsVisible ? 1 : 0)
                .disabled(!buttonsVisible)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).delay(0.5)) {
                introTextVisible = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(2)) {
                buttonsVisible = true
            }
        }
        .fullScreenCover(isPresented: $goToSignUp) {
            SignupView(profileCreated: .constant(false))
                .environmentObject(userViewModel)
        }
        .fullScreenCover(isPresented: $goToLogin) {
            LoginView(showLogin: .constant(false))
        }
    }
}

// MARK: - Preview
#Preview {
    WelcomeView()
}
