//
//  LobbyRoundResultView.swift
//  IOS - Quizzen
//
//  Ergebnis einer Runde (nicht der ganzen Lobby – die bleibt bestehen).
//  Zeigt ein kleines Podium für die ersten drei Plätze. Danach geht's
//  zurück in den Warteraum, wo die nächste Runde startet.
//

import SwiftUI

struct LobbyRoundResultView: View {
    @ObservedObject var session: LobbySession
    let roundNumber: Int

    @State private var appeared = false

    private var ranked: [(member: LobbyMember, score: Int)] {
        session.activeMembers
            .map { ($0, session.roundScore(of: $0.user_id)) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.username < $1.0.username }
    }

    private var myRank: Int? { ranked.firstIndex { $0.member.user_id == session.myUserId }.map { $0 + 1 } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: outcomeIcon)
                        .font(.system(size: 52))
                        .foregroundStyle(outcomeColor.gradient)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .rotationEffect(.degrees(appeared ? 0 : -30))
                    Text(outcomeTitle)
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .multilineTextAlignment(.center)
                    if let quiz = session.quiz {
                        Text(quiz.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 24)

                if ranked.count >= 2 { podium }
                standings
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                session.dismissRoundResult()
            } label: {
                Label("Zurück zur Lobby", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.45)) { appeared = true }
            UINotificationFeedbackGenerator().notificationOccurred(myRank == 1 ? .success : .warning)
        }
    }

    private var outcomeIcon: String { myRank == 1 ? "trophy.fill" : "flag.checkered" }
    private var outcomeColor: Color { myRank == 1 ? .yellow : .brandLight }
    private var outcomeTitle: String {
        switch myRank {
        case 1: String(localized: "Gewonnen! 🏆")
        case 2: String(localized: "Zweiter Platz!")
        case 3: String(localized: "Dritter Platz!")
        case .some(let rank): String(localized: "Platz \(rank)")
        case nil: String(localized: "Runde beendet")
        }
    }

    // MARK: Podium (Plätze 1–3)

    @ViewBuilder
    private var podium: some View {
        let top = Array(ranked.prefix(3))
        let order = [1, 0, 2].filter { $0 < top.count }

        HStack(alignment: .bottom, spacing: 12) {
            ForEach(order, id: \.self) { index in
                podiumColumn(top[index], rank: index + 1, height: [120, 90, 70][index])
            }
        }
    }

    private func podiumColumn(_ entry: (member: LobbyMember, score: Int), rank: Int, height: CGFloat) -> some View {
        let medal: Color = rank == 1 ? Color(hex: "E3B23C") : (rank == 2 ? Color(hex: "A7B0BA") : Color(hex: "B87333"))
        let isMe = entry.member.user_id == session.myUserId

        return VStack(spacing: 8) {
            ZStack(alignment: .top) {
                AvatarView(username: entry.member.username, url: entry.member.avatar_url, size: rank == 1 ? 68 : 54)
                    .overlay(Circle().stroke(medal, lineWidth: 3))
                    .padding(.top, rank == 1 ? 16 : 0)
                if rank == 1 {
                    Image(systemName: "crown.fill").foregroundStyle(.yellow)
                }
            }
            Text(isMe ? String(localized: "Du") : entry.member.username)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isMe ? Color.brandLight : .primary)
            VStack(spacing: 2) {
                Text("\(entry.score)")
                    .font(.system(.title3, design: .rounded).weight(.black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(medal.gradient, in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Gesamte Platzierung

    private var standings: some View {
        VStack(spacing: 8) {
            ForEach(Array(ranked.enumerated()), id: \.element.member.id) { index, entry in
                let isMe = entry.member.user_id == session.myUserId
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 26)
                    AvatarView(username: entry.member.username, url: entry.member.avatar_url, size: 36)
                    Text(isMe ? String(localized: "\(entry.member.username) (Du)") : entry.member.username)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.score)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .padding(10)
                .background(isMe ? Color.brand.opacity(0.15) : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
