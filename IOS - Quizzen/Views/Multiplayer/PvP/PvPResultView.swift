//
//  PvPResultView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 11.07.26.
//

import SwiftUI

struct PvPResultView: View {
    @ObservedObject var session: PvPSession
    let onDone: () -> Void

    @State private var appeared = false

    /// Abgebrochen, bevor ein Quiz gestartet wurde (z. B. im Warteraum verlassen)
    private var endedBeforeStart: Bool {
        session.phase == .cancelled && session.quiz == nil
    }

    private var outcome: (title: String, icon: String, color: Color) {
        if endedBeforeStart {
            return session.didIWin == true
                ? (String(localized: "\(session.opponentName) hat das Duell verlassen"), "door.left.hand.open", .secondary)
                : (String(localized: "Duell abgebrochen"), "xmark.circle", .secondary)
        }
        if session.phase == .cancelled {
            return session.didIWin == true
                ? (String(localized: "\(session.opponentName) hat aufgegeben"), "flag.fill", .green)
                : (String(localized: "Du hast aufgegeben"), "flag.fill", .secondary)
        }
        switch session.didIWin {
        case .some(true):  return ("Gewonnen!", "trophy.fill", .yellow)
        case .some(false): return (String(localized: "Verloren"), "hand.thumbsdown.fill", .red)
        case .none:        return ("Unentschieden!", "equal.circle.fill", .orange)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: outcome.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(outcome.color.gradient)
                        .scaleEffect(appeared ? 1 : 0.3)
                        .rotationEffect(.degrees(appeared ? 0 : -30))
                    Text(outcome.title)
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .multilineTextAlignment(.center)
                    if let quiz = session.quiz {
                        Text(quiz.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 24)

                if !endedBeforeStart {
                    scoreboard
                    breakdown
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onDone) {
                Label("Neues Duell", systemImage: "arrow.counterclockwise")
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
            if !endedBeforeStart {
                UINotificationFeedbackGenerator().notificationOccurred(session.didIWin == true ? .success : .warning)
            }
        }
    }

    private var scoreboard: some View {
        HStack {
            resultPlayer(name: "Du", account: session.me, score: session.myScore, isWinner: session.didIWin == true)
            Text(":")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(.secondary)
            resultPlayer(name: session.opponentName, account: session.opponent, score: session.opponentScore,
                         isWinner: session.didIWin == false)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }

    private func resultPlayer(name: String, account: Account?, score: Int, isWinner: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                AvatarView(username: account?.username ?? name, url: account?.avatarUrl, size: 68)
                    .overlay(Circle().stroke(isWinner ? Color.yellow : .clear, lineWidth: 3))
                    .padding(.top, 14)
                if isWinner {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                }
            }
            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(score)")
                .font(.system(size: 44, weight: .black, design: .rounded))
        }
        .frame(maxWidth: .infinity)
    }

    /// Frage für Frage: wer lag richtig?
    @ViewBuilder
    private var breakdown: some View {
        let count = session.totalQuestions
        if count > 0 {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Fragen").font(.headline)
                    Spacer()
                    Text("Du").frame(width: 44)
                    Text(String(session.opponentName.prefix(8))).frame(width: 64)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

                ForEach(0..<count, id: \.self) { index in
                    if index > 0 { Divider() }
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)
                        Text(session.question(at: index)?.question ?? "–")
                            .font(.subheadline)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        resultIcon(session.answer(of: session.myUserId, at: index)).frame(width: 44)
                        resultIcon(session.answer(of: session.opponentId, at: index)).frame(width: 64)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        }
    }

    @ViewBuilder
    private func resultIcon(_ answer: MatchAnswer?) -> some View {
        if let answer {
            if answer.is_correct {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if answer.answer == nil {
                Image(systemName: "clock.badge.xmark").foregroundStyle(.orange)
            } else {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
        } else {
            Text("–").foregroundStyle(.secondary)
        }
    }
}
