//
//  CompactBadgeHexagon.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.07.26.
//

import Foundation
import SwiftUI

/// Kleine Medaille für Vorschauen (Profil, öffentliches Profil).
struct CompactBadgeHexagon: View {
    let badge: Badge
    var size: CGFloat = 58
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 8) {
                BadgeMedalView(badge: badge, size: size)
                    .padding(.bottom, 4)
                Text(badge.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
