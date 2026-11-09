//
//  ProfileBadgeView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 31.07.26.
//

import Foundation
import SwiftUI

// MARK: - Badge Fortschritt
struct BadgeProgress {
    let type: BadgeType
    let currentValue: Int
    let level: Int
    let goalText: String
    let isMaxLevel: Bool
    
    init(type: BadgeType, currentValue: Int) {
        self.type = type
        self.currentValue = currentValue
        
        let thresholds = type.thresholds
        
        // Höchstes erreichtes Level finden
        var reachedLevel = 0
        for (index, threshold) in thresholds.enumerated() {
            if currentValue >= threshold {
                reachedLevel = index + 1
            }
        }
        self.level = reachedLevel
        self.isMaxLevel = reachedLevel >= thresholds.count
        
        self.goalText = "\(reachedLevel) von 10"
    }
}


// MARK: - ProfileBadgeView
struct ProfileBadgeView: View {
    @EnvironmentObject var statsManager: StatsManager
    var externalStats: GlobalStats? = nil

    private var badges: [Badge] {
        Badge.make(from: externalStats ?? statsManager.globalManager.stats)
    }

    private var earnedCount: Int { badges.filter { !$0.isLocked }.count }
    private var totalLevels: Int { badges.filter { !$0.isSpecial }.reduce(0) { $0 + $1.level } }
    private var maxLevels: Int { badges.filter { !$0.isSpecial }.reduce(0) { $0 + $1.maxLevel } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summary

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                    ForEach(badges) { badge in
                        BadgeHexagon(badge: badge)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Abzeichen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(earnedCount) von \(badges.count) freigeschaltet")
                        .font(.headline)
                    Text("Gesamt-Level \(totalLevels) / \(maxLevels)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "rosette")
                    .font(.largeTitle)
                    .foregroundStyle(LinearGradient(colors: BadgeTier.gold.rimColors, startPoint: .top, endPoint: .bottom))
            }
            ProgressView(value: Double(totalLevels), total: Double(max(maxLevels, 1)))
                .tint(Color(hex: "E3B23C"))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - BadgeHexagon (Zelle im Raster)
struct BadgeHexagon: View {
    let badge: Badge
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 10) {
                BadgeMedalView(badge: badge, size: 88)
                    .padding(.bottom, 6)

                Text(badge.name)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)

                if !badge.isSpecial {
                    ProgressView(value: badge.progressToNext)
                        .tint(badge.isLocked ? .gray : badge.color)
                        .frame(width: 64)
                    Text(badge.tier.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(badge.goal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            BadgeView(badge: badge)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - HexagonShape
nonisolated struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}
