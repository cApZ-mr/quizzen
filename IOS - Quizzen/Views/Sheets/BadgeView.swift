//
//  BadgeView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 22.06.26.
//

import Foundation
import SwiftUI

/// Detailansicht eines Abzeichens (als Sheet)
struct BadgeView: View {
    @Environment(\.dismiss) private var dismiss
    let badge: Badge

    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [badge.color.opacity(badge.isLocked ? 0.1 : 0.45), .clear],
                                                 center: .center, startRadius: 10, endRadius: 140))
                            .frame(width: 280, height: 280)
                        BadgeMedalView(badge: badge, size: 150)
                            .scaleEffect(appeared ? 1 : 0.6)
                            .rotation3DEffect(.degrees(appeared ? 0 : -90), axis: (x: 0, y: 1, z: 0))
                    }
                    .frame(height: 220)

                    VStack(spacing: 6) {
                        Text(badge.name)
                            .font(.system(.title, design: .rounded).weight(.bold))
                        Text(badge.isSpecial ? badge.goal : "\(badge.tier.name) · \(badge.goal)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if !badge.isSpecial {
                        progressCard
                        levelPath
                    }

                    Text(badge.explanation)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                }
                if !badge.isLocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareText)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.35)) { appeared = true }
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(badge.nextThreshold == nil ? String(localized: "Maximum erreicht") : String(localized: "Bis Level \(badge.level + 1)"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(badge.nextThreshold.map { "\(badge.currentValue) / \($0)" } ?? "\(badge.currentValue)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: badge.progressToNext)
                .tint(badge.color)
            Text(badge.unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Alle Level als Punkte, eingefärbt nach Stufe
    private var levelPath: some View {
        HStack(spacing: 6) {
            ForEach(1...badge.maxLevel, id: \.self) { level in
                let reached = level <= badge.level
                Circle()
                    .fill(reached
                          ? AnyShapeStyle(LinearGradient(colors: BadgeTier(level: level).rimColors, startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color(.tertiarySystemFill)))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("\(level)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(reached ? .black.opacity(0.7) : .secondary)
                    )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Level \(badge.level) von \(badge.maxLevel)")
    }

    private var shareText: String {
        let what = badge.isSpecial ? String(localized: "das Abzeichen „\(badge.name)“") : String(localized: "\(badge.tier.name) (Level \(badge.level)) im Abzeichen „\(badge.name)“")
        return String(localized: "Ich habe \(what) in Quizzen erreicht! 🏆\n\nLade dir die Quizzen App im App Store: \(AppVersionService.appStoreURL.absoluteString)")
    }
}
