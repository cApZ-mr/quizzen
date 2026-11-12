//
//  ProfileBanner.swift
//  IOS - Quizzen
//
//  Gerenderte Profil-Banner (keine Bilddateien nötig, scharf in jeder Größe).
//  Einige Banner werden über das Level freigeschaltet.
//

import SwiftUI

// MARK: - Katalog

enum ProfileBanner: String, CaseIterable, Identifiable {
    case quiz, ocean, sunset, forest, aurora, confetti, neon, galaxy, lava, gold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quiz:     String(localized: "Quizzen")
        case .ocean:    String(localized: "Ozean")
        case .sunset:   String(localized: "Sonnenuntergang")
        case .forest:   String(localized: "Wald")
        case .aurora:   String(localized: "Polarlicht")
        case .confetti: String(localized: "Konfetti")
        case .neon:     String(localized: "Neon")
        case .galaxy:   String(localized: "Galaxie")
        case .lava:     String(localized: "Vulkan")
        case .gold:     String(localized: "Gold")
        }
    }

    /// Ab welchem Level das Banner wählbar ist
    var requiredLevel: Int {
        switch self {
        case .quiz, .ocean, .sunset, .forest: 1
        case .aurora:   3
        case .confetti: 5
        case .neon:     7
        case .galaxy:   10
        case .lava:     15
        case .gold:     25
        }
    }

    /// Gespeicherte ID -> Banner. Alte Bild-Banner werden auf neue abgebildet.
    static func from(id: String?) -> ProfileBanner? {
        guard let id else { return nil }
        if let banner = ProfileBanner(rawValue: id) { return banner }
        switch id {
        case "landschaft": return .sunset
        case "night_sky":  return .galaxy
        default:           return .quiz
        }
    }
}

// MARK: - View

struct ProfileBannerView: View {
    /// nil = Standard-Banner
    let bannerId: String?

    private var banner: ProfileBanner { ProfileBanner.from(id: bannerId) ?? .quiz }

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch banner {
        case .quiz:     quiz(size)
        case .ocean:    ocean(size)
        case .sunset:   sunset(size)
        case .forest:   forest(size)
        case .aurora:   aurora(size)
        case .confetti: confetti(size)
        case .neon:     neon(size)
        case .galaxy:   galaxy(size)
        case .lava:     lava(size)
        case .gold:     gold(size)
        }
    }

    // MARK: Designs

    private func quiz(_ size: CGSize) -> some View {
        let symbols = ["questionmark", "lightbulb.fill", "star.fill", "brain.head.profile.fill", "trophy.fill", "globe.europe.africa.fill"]
        return ZStack {
            LinearGradient(colors: [Color.brandLight, Color.brand, Color(hex: "021B44")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, canvasSize in
                let step: CGFloat = 46
                var index = 0
                for row in 0...Int(canvasSize.height / step) + 1 {
                    for col in 0...Int(canvasSize.width / step) + 1 {
                        let x = CGFloat(col) * step + (row.isMultiple(of: 2) ? step / 2 : 0)
                        let y = CGFloat(row) * step
                        let symbol = context.resolve(Image(systemName: symbols[index % symbols.count]))
                        context.opacity = 0.13
                        context.draw(symbol, in: CGRect(x: x - 9, y: y - 9, width: 18, height: 18))
                        index += 1
                    }
                }
            }
            .foregroundStyle(.white)
            RadialGradient(colors: [.white.opacity(0.25), .clear], center: .topTrailing, startRadius: 0, endRadius: size.width * 0.7)
        }
    }

    private func ocean(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "7FD8F5"), Color(hex: "0B6FB8"), Color(hex: "06294F")],
                           startPoint: .top, endPoint: .bottom)
            ForEach(0..<4, id: \.self) { layer in
                WaveShape(amplitude: 10 + CGFloat(layer) * 4, frequency: 1.4 + Double(layer) * 0.3, phase: Double(layer) * 1.3)
                    .fill(Color.white.opacity(0.08 + Double(layer) * 0.04))
                    .offset(y: size.height * (0.35 + CGFloat(layer) * 0.15))
            }
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: size.height * 0.22)
                .blur(radius: 1)
                .position(x: size.width * 0.8, y: size.height * 0.22)
        }
    }

    private func sunset(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "2B1055"), Color(hex: "D53A9D"), Color(hex: "FF8C42"), Color(hex: "FFD166")],
                           startPoint: .top, endPoint: .bottom)
            // Sonne mit Streifen
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "FFE29A"), Color(hex: "FF7A59")], startPoint: .top, endPoint: .bottom))
                .frame(width: size.height * 0.7)
                .mask(
                    VStack(spacing: 4) {
                        Rectangle().frame(height: size.height * 0.35)
                        ForEach(0..<5, id: \.self) { i in Rectangle().frame(height: 6 - CGFloat(i)) }
                        Spacer()
                    }
                    .frame(height: size.height * 0.7)
                )
                .position(x: size.width * 0.5, y: size.height * 0.62)
            MountainShape(peaks: [0.25, 0.55, 0.35, 0.7, 0.4], baseline: 0.78)
                .fill(Color(hex: "3D1A4F").opacity(0.85))
            MountainShape(peaks: [0.6, 0.4, 0.75, 0.5], baseline: 0.88)
                .fill(Color(hex: "1E0B2B"))
        }
    }

    private func forest(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "B9E4C9"), Color(hex: "3E8E5E"), Color(hex: "0E2E1D")],
                           startPoint: .top, endPoint: .bottom)
            ForEach(0..<3, id: \.self) { layer in
                TreeLineShape(count: 9 + layer * 4, seed: layer * 7 + 3, heightFactor: 0.45 - CGFloat(layer) * 0.08)
                    .fill(Color(hex: ["2F6B47", "1F4D33", "0C2618"][layer]))
                    .offset(y: CGFloat(layer) * size.height * 0.1)
            }
            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: size.height * 0.18)
                .blur(radius: 6)
                .position(x: size.width * 0.2, y: size.height * 0.2)
        }
    }

    private func aurora(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "020617"), Color(hex: "0B1E3A")], startPoint: .top, endPoint: .bottom)
            starField(count: 60, seed: 11, size: size)
            Ellipse().fill(Color.green.opacity(0.55)).frame(width: size.width * 0.9, height: size.height * 0.35)
                .rotationEffect(.degrees(-12)).offset(x: -size.width * 0.1, y: -size.height * 0.05).blur(radius: 28)
            Ellipse().fill(Color.teal.opacity(0.6)).frame(width: size.width * 0.7, height: size.height * 0.25)
                .rotationEffect(.degrees(8)).offset(x: size.width * 0.2, y: size.height * 0.05).blur(radius: 24)
            Ellipse().fill(Color.purple.opacity(0.5)).frame(width: size.width * 0.6, height: size.height * 0.3)
                .offset(x: size.width * 0.3, y: -size.height * 0.2).blur(radius: 30)
        }
    }

    private func confetti(_ size: CGSize) -> some View {
        let colors: [Color] = [.pink, .yellow, .cyan, .orange, .green, .purple, .white]
        return ZStack {
            LinearGradient(colors: [Color(hex: "1A1033"), Color(hex: "3A1C71")], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, canvasSize in
                var rng = SeededRandom(seed: 42)
                for i in 0..<90 {
                    let x = rng.next() * canvasSize.width
                    let y = rng.next() * canvasSize.height
                    let w = 4 + rng.next() * 8
                    let rect = CGRect(x: x, y: y, width: w, height: w * (i.isMultiple(of: 3) ? 1 : 0.45))
                    var piece = context
                    piece.translateBy(x: rect.midX, y: rect.midY)
                    piece.rotate(by: .degrees(rng.next() * 360))
                    let local = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
                    let path = i.isMultiple(of: 3) ? Path(ellipseIn: local) : Path(roundedRect: local, cornerRadius: 1)
                    piece.fill(path, with: .color(colors[i % colors.count].opacity(0.85)))
                }
            }
        }
    }

    private func neon(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0D0221"), Color(hex: "261447"), Color(hex: "541388")],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "FFD319"), Color(hex: "FF2975")], startPoint: .top, endPoint: .bottom))
                .frame(width: size.height * 0.6)
                .position(x: size.width * 0.5, y: size.height * 0.5)
                .shadow(color: Color(hex: "FF2975"), radius: 20)
            // Perspektivisches Raster
            Canvas { context, canvasSize in
                let horizon = canvasSize.height * 0.62
                context.fill(Path(CGRect(x: 0, y: horizon, width: canvasSize.width, height: canvasSize.height - horizon)),
                             with: .color(Color(hex: "0D0221")))
                let lineColor = GraphicsContext.Shading.color(Color(hex: "FF2975").opacity(0.9))
                for i in 0..<8 {
                    let t = pow(CGFloat(i) / 7, 1.8)
                    let y = horizon + t * (canvasSize.height - horizon)
                    context.stroke(Path { $0.move(to: CGPoint(x: 0, y: y)); $0.addLine(to: CGPoint(x: canvasSize.width, y: y)) },
                                   with: lineColor, lineWidth: 1.2)
                }
                for i in -10...10 {
                    let bottomX = canvasSize.width / 2 + CGFloat(i) * canvasSize.width / 8
                    context.stroke(Path { $0.move(to: CGPoint(x: canvasSize.width / 2 + CGFloat(i) * 6, y: horizon))
                                          $0.addLine(to: CGPoint(x: bottomX, y: canvasSize.height)) },
                                   with: lineColor, lineWidth: 1)
                }
            }
        }
    }

    private func galaxy(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "05010F"), Color(hex: "1B0B3A")], startPoint: .top, endPoint: .bottom)
            Ellipse().fill(Color.purple.opacity(0.6)).frame(width: size.width * 0.8, height: size.height * 0.4)
                .rotationEffect(.degrees(-20)).blur(radius: 30)
            Ellipse().fill(Color.pink.opacity(0.4)).frame(width: size.width * 0.4, height: size.height * 0.25)
                .rotationEffect(.degrees(-20)).offset(x: size.width * 0.15).blur(radius: 22)
            Ellipse().fill(Color.blue.opacity(0.45)).frame(width: size.width * 0.35, height: size.height * 0.3)
                .offset(x: -size.width * 0.25, y: size.height * 0.1).blur(radius: 26)
            starField(count: 140, seed: 7, size: size)
        }
    }

    private func lava(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1A0000"), Color(hex: "5C0A0A")], startPoint: .top, endPoint: .bottom)
            ForEach(0..<6, id: \.self) { i in
                let blob = Self.blob(i)
                Circle()
                    .fill(i.isMultiple(of: 2) ? Color.orange : Color.red)
                    .frame(width: size.width * blob.scale)
                    .position(x: size.width * blob.x, y: size.height * (0.3 + blob.y * 0.8))
                    .blur(radius: 18)
                    .opacity(0.8)
            }
            MountainShape(peaks: [0.35, 0.8, 0.3], baseline: 0.92)
                .fill(Color.black.opacity(0.85))
        }
    }

    private func gold(_ size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1C1405"), Color(hex: "3D2B07")], startPoint: .top, endPoint: .bottom)
            // Strahlen
            ForEach(0..<18, id: \.self) { i in
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: "FFD86B").opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: size.width * 1.2, height: 10)
                    .offset(x: size.width * 0.6)
                    .rotationEffect(.degrees(Double(i) * 20), anchor: .center)
            }
            .position(x: size.width * 0.5, y: size.height * 0.5)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "FFF1B8"), Color(hex: "E3B23C"), Color(hex: "8A6212")],
                                     center: .center, startRadius: 0, endRadius: size.height * 0.35))
                .frame(width: size.height * 0.55)
                .shadow(color: Color(hex: "E3B23C").opacity(0.8), radius: 24)
            Image(systemName: "crown.fill")
                .font(.system(size: size.height * 0.22))
                .foregroundStyle(Color(hex: "5A3E05"))
        }
    }

    // MARK: Helfer

    private static func blob(_ i: Int) -> (x: CGFloat, y: CGFloat, scale: CGFloat) {
        var rng = SeededRandom(seed: UInt64(i * 13 + 5))
        return (rng.next(), rng.next(), 0.25 + rng.next() * 0.3)
    }

    private func starField(count: Int, seed: UInt64, size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var rng = SeededRandom(seed: seed)
            for _ in 0..<count {
                let r = 0.5 + rng.next() * 1.6
                let rect = CGRect(x: rng.next() * canvasSize.width, y: rng.next() * canvasSize.height, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.4 + rng.next() * 0.6)))
            }
        }
    }
}

// MARK: - Formen

nonisolated private struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: Double
    var phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        for x in stride(from: 0, through: rect.width, by: 4) {
            let y = sin(Double(x / rect.width) * .pi * 2 * frequency + phase) * Double(amplitude)
            path.addLine(to: CGPoint(x: x, y: CGFloat(y)))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

nonisolated private struct MountainShape: Shape {
    /// Gipfelhöhen 0…1 (Anteil der Höhe von oben)
    let peaks: [CGFloat]
    let baseline: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * baseline))
        let step = rect.width / CGFloat(peaks.count)
        for (i, peak) in peaks.enumerated() {
            path.addLine(to: CGPoint(x: step * (CGFloat(i) + 0.5), y: rect.height * peak))
            path.addLine(to: CGPoint(x: step * CGFloat(i + 1), y: rect.height * baseline))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

nonisolated private struct TreeLineShape: Shape {
    let count: Int
    let seed: Int
    let heightFactor: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var rng = SeededRandom(seed: UInt64(seed))
        let width = rect.width / CGFloat(count)
        path.move(to: CGPoint(x: 0, y: rect.height))
        for i in 0..<count {
            let h = rect.height * heightFactor * (0.7 + rng.next() * 0.6)
            let x = CGFloat(i) * width
            path.addLine(to: CGPoint(x: x, y: rect.height - h * 0.2))
            path.addLine(to: CGPoint(x: x + width / 2, y: rect.height - h))
            path.addLine(to: CGPoint(x: x + width, y: rect.height - h * 0.2))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// Deterministischer Zufall, damit Banner bei jedem Rendern gleich aussehen.
nonisolated struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

#Preview {
    ScrollView {
        VStack {
            ForEach(ProfileBanner.allCases) { banner in
                ProfileBannerView(bannerId: banner.id)
                    .frame(height: 140)
                    .overlay(alignment: .bottomLeading) { Text(banner.displayName).padding(8).foregroundStyle(.white) }
            }
        }
    }
}
