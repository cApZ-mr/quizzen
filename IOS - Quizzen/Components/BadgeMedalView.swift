//
//  BadgeMedalView.swift
//  IOS - Quizzen
//
//  Medaillen-Optik für Abzeichen: metallischer Rahmen je Stufe
//  (Bronze → Diamant), farbiger Kern, Glanzlicht und Level-Plakette.
//

import SwiftUI

struct BadgeMedalView: View {
    let badge: Badge
    var size: CGFloat = 88
    /// Level-Plakette unten anzeigen
    var showsLevel: Bool = true

    private var tier: BadgeTier { badge.tier }
    private var isEarned: Bool { !badge.isLocked }

    var body: some View {
        ZStack {
            // Schatten/Glow
            hexagon
                .fill(isEarned ? badge.color.opacity(0.45) : .clear)
                .blur(radius: size * 0.12)
                .offset(y: size * 0.04)

            // Metallischer Rahmen
            hexagon
                .fill(AngularGradient(colors: tier.rimColors + [tier.rimColors[0]], center: .center, angle: .degrees(-60)))
            hexagon
                .stroke(.white.opacity(0.35), lineWidth: max(1, size * 0.012))

            // Farbiger Kern
            hexagon
                .fill(
                    LinearGradient(colors: coreColors, startPoint: .top, endPoint: .bottom)
                )
                .padding(size * 0.1)
                .overlay(
                    hexagon
                        .stroke(.black.opacity(0.25), lineWidth: max(1, size * 0.02))
                        .padding(size * 0.1)
                )

            // Glanzlicht
            hexagon
                .fill(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center))
                .padding(size * 0.1)
                .mask(Rectangle().frame(height: size * 0.5).offset(y: -size * 0.25))

            Image(systemName: badge.icon)
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: size * 0.03, y: size * 0.02)

            if showsLevel {
                levelPlate
                    .offset(y: size * 0.44)
            }
        }
        .frame(width: size, height: size)
        .saturation(isEarned ? 1 : 0)
        .opacity(isEarned ? 1 : 0.55)
        .accessibilityElement()
        .accessibilityLabel("\(badge.name), \(tier.name)\(badge.isSpecial ? "" : ", Level \(badge.level)")")
    }

    /// Spitze oben (Wabe senkrecht)
    private var hexagon: some Shape {
        HexagonShape().rotation(.degrees(30))
    }

    private var coreColors: [Color] {
        [badge.color.mix(with: .white, by: 0.25), badge.color, badge.color.mix(with: .black, by: 0.45)]
    }

    @ViewBuilder
    private var levelPlate: some View {
        Group {
            if badge.isSpecial {
                Image(systemName: "star.fill")
            } else if isEarned {
                Text("\(badge.level)")
            } else {
                Image(systemName: "lock.fill")
            }
        }
        .font(.system(size: size * 0.14, weight: .black, design: .rounded))
        .foregroundStyle(tier == .none ? .white : Color.black.opacity(0.75))
        .padding(.horizontal, size * 0.09)
        .frame(minWidth: size * 0.3, minHeight: size * 0.2)
        .background(
            Capsule().fill(LinearGradient(colors: tier.rimColors, startPoint: .top, endPoint: .bottom))
        )
        .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

#Preview {
    let stats = GlobalStats(totalAnswers: 900, correctAnswers: 700, falseAnswers: 200, quizzesPlayed: 120,
                            currentStreak: 2, bestStreak: 40)
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 24) {
        ForEach(Badge.make(from: stats)) { BadgeMedalView(badge: $0) }
    }
    .padding()
    .background(Color.black)
}
