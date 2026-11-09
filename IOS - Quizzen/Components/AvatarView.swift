//
//  AvatarView.swift
//  IOS - Quizzen
//
//  Einheitlicher Avatar: Bild per URL, sonst Initialen auf Farbfläche.
//

import SwiftUI

struct AvatarView: View {
    let username: String
    let url: String?
    var size: CGFloat = 44
    var image: Image? = nil

    var body: some View {
        Group {
            if let image {
                image.resizable().scaledToFill()
            } else if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { phase in
                    if let loaded = phase.image {
                        loaded.resizable().scaledToFill()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: some View {
        ZStack {
            Circle().fill(color.gradient)
            Text(String(username.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    /// Stabile Farbe pro Nutzername
    private var color: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .green, .red]
        let hash = username.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[hash % palette.count]
    }
}
