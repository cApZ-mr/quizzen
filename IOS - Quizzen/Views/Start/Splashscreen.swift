//
//  Splashscreen.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 15.05.26.
//
//  Animierter Start: Das „Q“ springt herein, ein Lichtring pulsiert,
//  Quiz-Symbole fliegen heraus und das Quizzen-Logo erscheint darunter.
//  Gesamtdauer ca. 1,3 s. Bei „Bewegung reduzieren“ wird nur eingeblendet.
//

import SwiftUI

struct SplashScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showQ = false
    @State private var showRing = false
    @State private var burst = false
    @State private var showLogo = false
    @State private var spin = false

    /// Symbole, die aus dem Q herausfliegen
    private let orbiters: [(icon: String, color: Color)] = [
        ("questionmark", .white), ("flag.fill", .teal), ("bolt.fill", .yellow),
        ("star.fill", .orange), ("globe.europe.africa.fill", .cyan), ("trophy.fill", Color(hex: "E3B23C")),
        ("lightbulb.fill", .yellow), ("brain.head.profile.fill", .pink),
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 18) {
                ZStack {
                    pulseRing
                    orbitingSymbols
                    qMark
                }
                .frame(width: 260, height: 260)
                .offset(y: showLogo ? -6 : 24)

                Image("AppLogoLight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 230)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: showLogo ? 230 : 0)
                    }
                    .offset(y: showLogo ? 0 : 12)
                    .opacity(showLogo ? 1 : 0)
            }
        }
        .task { await play() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quizzen")
    }

    // MARK: - Ebenen

    private var background: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color.brand.opacity(0.55), Color.brand.opacity(0.12), .clear],
                           center: .center, startRadius: 10, endRadius: showRing ? 420 : 120)
                .opacity(showQ ? 1 : 0)
        }
        .ignoresSafeArea()
    }

    private var qMark: some View {
        Image("AppIconDark")
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 150)
            // „Screen“ macht den schwarzen Icon-Hintergrund durchsichtig – nur das blaue Q bleibt
            .blendMode(.screen)
            .background {
                Circle()
                    .fill(Color.brandLight.opacity(showRing ? 0.35 : 0))
                    .blur(radius: 40)
            }
            .scaleEffect(showQ ? (showLogo ? 0.9 : 1) : 0.2)
            .rotationEffect(.degrees(showQ ? 0 : -35))
            .opacity(showQ ? 1 : 0)
    }

    private var pulseRing: some View {
        ZStack {
            Circle()
                .stroke(Color.brandLight.opacity(0.9), lineWidth: 3)
                .scaleEffect(showRing ? 1.6 : 0.5)
                .opacity(showRing ? 0 : 0.9)
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .scaleEffect(showRing ? 2.1 : 0.5)
                .opacity(showRing ? 0 : 0.6)
        }
        .frame(width: 150, height: 150)
    }

    private var orbitingSymbols: some View {
        ZStack {
            ForEach(Array(orbiters.enumerated()), id: \.offset) { index, item in
                let angle = Double(index) / Double(orbiters.count) * 360
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(item.color)
                    .shadow(color: item.color.opacity(0.6), radius: 6)
                    .rotationEffect(.degrees(spin ? -angle - 40 : -angle))   // Symbol bleibt aufrecht
                    .offset(y: burst ? -118 : 0)
                    .rotationEffect(.degrees(angle + (spin ? 40 : 0)))
                    .scaleEffect(burst ? 1 : 0.1)
                    .opacity(burst ? 1 : 0)
            }
        }
    }

    // MARK: - Ablauf

    private func play() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                showQ = true; showRing = true; burst = true; showLogo = true
            }
            return
        }
        withAnimation(.spring(duration: 0.55, bounce: 0.45)) { showQ = true }
        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.easeOut(duration: 0.9)) { showRing = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(duration: 0.7, bounce: 0.35)) { burst = true }
        withAnimation(.easeInOut(duration: 2.5)) { spin = true }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.spring(duration: 0.6, bounce: 0.25)) { showLogo = true }
    }
}

// MARK: - PREVIEW
#Preview {
    SplashScreen()
}
