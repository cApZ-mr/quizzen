//
//  QuizCoverView.swift
//  IOS - Quizzen
//
//  Gerenderte Quiz-Cover: passendes Motiv pro Quiz statt statischer
//  Text-Poster. Skaliert auf jede Größe (Karte, Karussell, Detail-Header).
//

import SwiftUI

// MARK: - Theme

/// Beschreibt, wie das Cover eines Quiz aussieht.
struct QuizCoverTheme {
    enum Motif {
        /// Collage aus echten Flaggen (ISO-Codes = Asset-Namen)
        case flags([String])
        /// Großes Hauptsymbol + verstreute Nebensymbole
        case symbols(main: String, scattered: [String])
        /// Abflugtafel mit Flughafen-Codes
        case departureBoard([String])
    }

    let colors: [Color]
    let motif: Motif

    static func forQuiz(_ quiz: QuizDetail) -> QuizCoverTheme {
        switch quiz.id {
        case "Flags":         return flags(["de", "br", "jp", "za", "us", "in", "fr", "au", "kr"], .indigo)
        case "Capitals":      return .init(colors: [.teal, .indigo],
                                           motif: .symbols(main: "globe.europe.africa.fill", scattered: ["building.columns.fill", "mappin.and.ellipse", "building.2.fill"]))
        case "Basics":        return .init(colors: [.orange, .pink],
                                           motif: .symbols(main: "brain.head.profile.fill", scattered: ["lightbulb.max.fill", "questionmark", "atom", "book.fill"]))
        case "Aviation":      return .init(colors: [Color(hex: "1B2A4A"), .black],
                                           motif: .departureBoard(["FRA", "JFK", "HKG", "CDG", "BER", "GRU"]))
        case "History":       return .init(colors: [Color(hex: "8B5A2B"), Color(hex: "3B2412")],
                                           motif: .symbols(main: "building.columns.fill", scattered: ["scroll.fill", "crown.fill", "shield.fill", "hourglass"]))
        case "Science":       return .init(colors: [.mint, Color(hex: "0B4F6C")],
                                           motif: .symbols(main: "atom", scattered: ["flask.fill", "leaf.fill", "moon.stars.fill", "bolt.fill"]))
        case "Sports":        return .init(colors: [.green, Color(hex: "0B3D1E")],
                                           motif: .symbols(main: "trophy.fill", scattered: ["soccerball", "basketball.fill", "medal.fill", "tennisball.fill"]))
        case "Movies":        return .init(colors: [.purple, .black],
                                           motif: .symbols(main: "film.fill", scattered: ["popcorn.fill", "tv.fill", "star.fill", "ticket.fill"]))
        case "HarryPotter":   return .init(colors: [Color(hex: "5B1A1A"), Color(hex: "1E1B3A")],
                                           motif: .symbols(main: "wand.and.stars", scattered: ["sparkles", "moon.stars.fill", "book.closed.fill"]))
        case "SportsNBA":     return .init(colors: [Color(hex: "C8102E"), Color(hex: "1D428A")],
                                           motif: .symbols(main: "basketball.fill", scattered: ["figure.basketball", "trophy.fill", "star.fill", "sportscourt.fill"]))
        case "SportsBundesliga": return .init(colors: [Color(hex: "D3010C"), .black],
                                           motif: .symbols(main: "soccerball", scattered: ["flag.fill", "trophy.fill", "sportscourt.fill", "megaphone.fill"]))
        case "Music":         return .init(colors: [Color(hex: "7B2FF7"), Color(hex: "F72585")],
                                           motif: .symbols(main: "music.note", scattered: ["guitars.fill", "headphones", "waveform", "music.mic"]))
        case "Runways":       return .init(colors: [Color(hex: "1B2A4A"), Color(hex: "0B132B")],
                                           motif: .symbols(main: "airplane.circle.fill", scattered: ["location.north.line.fill", "antenna.radiowaves.left.and.right", "globe", "airplane"]))

        default:
            return fallback(for: quiz.categoryId)
        }
    }

    private static func flags(_ codes: [String], _ tint: Color) -> QuizCoverTheme {
        .init(colors: [tint, .black], motif: .flags(codes))
    }

    private static func fallback(for categoryId: String) -> QuizCoverTheme {
        let symbol = QuizCatalog.all.first { $0.categoryId == categoryId }?.icon ?? "questionmark"
        return .init(colors: [.brand, .black], motif: .symbols(main: symbol, scattered: ["questionmark", "star.fill", "sparkles"]))
    }
}

// MARK: - View

struct QuizCoverView: View {
    let quiz: QuizDetail
    /// Titel + Schwierigkeit unten einblenden (Karussell/Detail)
    var showsTitle: Bool = false

    private var theme: QuizCoverTheme { .forQuiz(quiz) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

                motif(in: size)

                if showsTitle {
                    titleOverlay
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .clipped()
        .accessibilityElement()
        .accessibilityLabel("Cover: \(quiz.title)")
    }

    @ViewBuilder
    private func motif(in size: CGSize) -> some View {
        switch theme.motif {
        case .flags(let codes):
            flagCollage(codes, size: size)
        case .symbols(let main, let scattered):
            symbolMotif(main: main, scattered: scattered, size: size)
        case .departureBoard(let codes):
            departureBoard(codes, size: size)
        }
    }

    // Schräg gelegte Flaggen-Collage
    private func flagCollage(_ codes: [String], size: CGSize) -> some View {
        let columns = 3
        let tileWidth = size.width / 2.2
        let tileHeight = tileWidth * 0.66
        return VStack(spacing: tileHeight * 0.18) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: tileWidth * 0.12) {
                    ForEach(0..<columns, id: \.self) { col in
                        let code = codes[(row * columns + col) % codes.count]
                        FlagImage(name: code, width: tileWidth, height: tileHeight)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? -tileWidth * 0.3 : tileWidth * 0.3)
            }
        }
        .rotationEffect(.degrees(-14))
        .frame(width: size.width, height: size.height)
        .overlay(
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
        )
    }

    // Großes Symbol rechts unten + verstreute Deko-Symbole
    private func symbolMotif(main: String, scattered: [String], size: CGSize) -> some View {
        let base = min(size.width, size.height)
        // Feste, aber pro Quiz unterschiedliche Positionen (deterministisch)
        let seed = quiz.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let spots: [(CGFloat, CGFloat, Double)] = [(0.18, 0.22, -18), (0.42, 0.12, 12), (0.12, 0.62, 20), (0.36, 0.48, -8)]

        return ZStack {
            ForEach(Array(spots.enumerated()), id: \.offset) { index, spot in
                Image(systemName: scattered[(index + seed) % scattered.count])
                    .font(.system(size: base * (index.isMultiple(of: 2) ? 0.16 : 0.11), weight: .bold))
                    .foregroundStyle(.white.opacity(0.22))
                    .rotationEffect(.degrees(spot.2))
                    .position(x: size.width * spot.0, y: size.height * spot.1)
            }

            Image(systemName: main)
                .font(.system(size: base * 0.62, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .rotationEffect(.degrees(-8))
                .position(x: size.width * 0.70, y: size.height * (showsTitle ? 0.40 : 0.55))
        }
    }

    // Abflugtafel im Split-Flap-Stil
    private func departureBoard(_ codes: [String], size: CGSize) -> some View {
        let fontSize = min(size.width / 7.5, size.height / 5)
        return VStack(alignment: .leading, spacing: fontSize * 0.25) {
            ForEach(Array(codes.prefix(4).enumerated()), id: \.offset) { index, code in
                HStack(spacing: fontSize * 0.3) {
                    Image(systemName: index.isMultiple(of: 2) ? "airplane.departure" : "airplane.arrival")
                        .font(.system(size: fontSize * 0.6))
                        .foregroundStyle(.yellow.opacity(0.8))
                    HStack(spacing: 2) {
                        ForEach(Array(code), id: \.self) { letter in
                            Text(String(letter))
                                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, fontSize * 0.08)
                                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                .opacity(1 - Double(index) * 0.18)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var titleOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer()
            Text(quiz.title)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
        )
    }
}

#Preview {
    let quizzes = DataService.loadAllQuizzes()
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            ForEach(quizzes) { quiz in
                QuizCoverView(quiz: quiz, showsTitle: true)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
    }
}
