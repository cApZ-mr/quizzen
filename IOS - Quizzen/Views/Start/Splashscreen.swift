//
//  Splashscreen.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 15.05.26.
//

import SwiftUI

struct SplashScreen: View {
    var body: some View {
        ZStack {
            VStack {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
            }
        }
    }
}

// MARK: - PREVIEW
#Preview {
    SplashScreen()
}
