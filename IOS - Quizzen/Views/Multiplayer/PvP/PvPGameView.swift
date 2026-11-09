//
//  PvPGameView.swift
//  IOS - Quizzen
//
//  Spielansicht im Duell. Alle Zustände kommen aus der PvPSession
//  (Server-Wahrheit) – die View hält nur die Antwort-Reihenfolge.
//

import Foundation
import SwiftUI

struct PvPGameView: View {
    @ObservedObject var session: PvPSession

    @State private var options: [QuizOption] = []
    @State private var optionsIndex: Int = -1
    @State private var pendingChoice: String?

    var body: some View {
        VStack(spacing: 16) {
            scoreBar
            progressDots

            if let question = session.currentQuestion {
                questionCard(question)
                Spacer(minLength: 0)
                optionsList
                statusLine
            } else {
                Spacer()
                ProgressView("Frage wird geladen…")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .onAppear(perform: prepareOptions)
        .onChange(of: session.currentIndex) { _, _ in prepareOptions() }
        .onChange(of: session.match?.quiz_id) { _, _ in prepareOptions() }
        .onChange(of: session.isRevealing) { _, revealing in
            guard revealing else { return }
            let correct = session.myCurrentAnswer?.is_correct ?? false
            UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        }
    }

    // MARK: Kopf: Spieler, Punkte, Timer

    private var scoreBar: some View {
        HStack(alignment: .center) {
            playerScore(name: "Du", account: session.me, score: session.myScore,
                        answered: session.myCurrentAnswer != nil, isMe: true)
            Spacer()
            timerRing
            Spacer()
            playerScore(name: session.opponentName, account: session.opponent, score: session.opponentScore,
                        answered: session.opponentCurrentAnswer != nil, isMe: false)
        }
        .padding(.top, 8)
    }

    private func playerScore(name: String, account: Account?, score: Int, answered: Bool, isMe: Bool) -> some View {
        HStack(spacing: 10) {
            if !isMe { scoreText(score, isMe: false) }
            VStack(spacing: 4) {
                AvatarView(username: account?.username ?? name, url: account?.avatarUrl, size: 42)
                    .overlay(alignment: .bottomTrailing) {
                        if answered && !session.isRevealing {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white, .green)
                                .offset(x: 3, y: 3)
                                .transition(.scale)
                        } else if !isMe && session.connection == .connected && !session.opponentOnline {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.gray, in: Circle())
                                .offset(x: 3, y: 3)
                        }
                    }
                Text(name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 70)
            }
            if isMe { scoreText(score, isMe: true) }
        }
        .animation(.spring(duration: 0.3), value: answered)
    }

    private func scoreText(_ score: Int, isMe: Bool) -> some View {
        Text("\(score)")
            .font(.system(size: 30, weight: .black, design: .rounded))
            .foregroundStyle(isMe ? Color.brandLight : .primary)
            .contentTransition(.numericText())
            .animation(.spring, value: score)
    }

    private var timerRing: some View {
        let duration = Double(session.match?.duration ?? 20)
        let remaining = session.remainingTime
        let fraction = duration > 0 ? remaining / duration : 0
        let color: Color = remaining <= 5 ? .red : (remaining <= 10 ? .orange : .brandLight)

        return ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: fraction)
            VStack(spacing: 0) {
                Text("\(Int(remaining.rounded(.up)))")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text("\(session.currentIndex + 1)/\(session.totalQuestions)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 58, height: 58)
        .accessibilityElement()
        .accessibilityLabel("Frage \(session.currentIndex + 1) von \(session.totalQuestions), noch \(Int(remaining)) Sekunden")
    }

    /// Ein Punkt pro Frage: grün/rot für eigene Ergebnisse
    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(session.totalQuestions, 1), id: \.self) { index in
                let answer = session.answer(of: session.myUserId, at: index)
                Capsule()
                    .fill(dotColor(index: index, answer: answer))
                    .frame(height: 5)
            }
        }
    }

    private func dotColor(index: Int, answer: MatchAnswer?) -> Color {
        if index == session.currentIndex && !session.isRevealing { return Color.brandLight }
        guard let answer, index < session.currentIndex || session.isRevealing else { return Color(.tertiarySystemFill) }
        return answer.is_correct ? .green : .red
    }

    // MARK: Frage

    private func questionCard(_ question: Question) -> some View {
        VStack(spacing: 14) {
            if let imageName = question.imageName, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
            }
            Text(question.prompt(quizId: session.quiz?.id ?? ""))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .id(session.currentIndex)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }

    // MARK: Antworten

    private var optionsList: some View {
        VStack(spacing: 10) {
            ForEach(options) { option in
                Button {
                    choose(option)
                } label: {
                    optionLabel(option)
                }
                .buttonStyle(.plain)
                .disabled(session.hasAnsweredCurrent || session.isRevealing || pendingChoice != nil)
            }
        }
    }

    private func optionLabel(_ option: QuizOption) -> some View {
        let myChoice = session.myCurrentAnswer?.answer ?? pendingChoice
        let isMine = myChoice == option.text
        let isOpponents = session.isRevealing && session.opponentCurrentAnswer?.answer == option.text
        let revealing = session.isRevealing

        let background: Color = {
            if revealing {
                if option.isCorrect { return .green }
                if isMine { return .red }
                return Color(.secondarySystemGroupedBackground)
            }
            return isMine ? Color.brand : Color(.secondarySystemGroupedBackground)
        }()
        let foreground: Color = (revealing && (option.isCorrect || isMine)) || (!revealing && isMine) ? .white : .primary

        return HStack(spacing: 10) {
            Text(option.text)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isOpponents {
                AvatarView(username: session.opponentName, url: session.opponent?.avatarUrl, size: 24)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .accessibilityLabel("\(session.opponentName) hat das gewählt")
            }
            if revealing && option.isCorrect {
                Image(systemName: "checkmark.circle.fill")
            } else if revealing && isMine {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: 16))
        .opacity(revealing && !option.isCorrect && !isMine && !isOpponents ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: revealing)
    }

    private var statusLine: some View {
        Group {
            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if session.isRevealing {
                let me = session.myCurrentAnswer?.is_correct ?? false
                let them = session.opponentCurrentAnswer?.is_correct ?? false
                Text(revealText(me: me, them: them))
                    .foregroundStyle(me ? .green : .secondary)
            } else if session.hasAnsweredCurrent || pendingChoice != nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(session.opponentCurrentAnswer != nil
                         ? "Auflösung kommt…"
                         : "Warte auf \(session.opponentName)…")
                }
                .foregroundStyle(.secondary)
            } else if session.opponentCurrentAnswer != nil {
                Label("\(session.opponentName) hat schon geantwortet", systemImage: "bolt.fill")
                    .foregroundStyle(.orange)
            } else {
                Text(" ")
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(height: 22)
    }

    private func revealText(me: Bool, them: Bool) -> String {
        switch (me, them) {
        case (true, true):   "Beide richtig! +1 für jeden"
        case (true, false):  "Punkt für dich! 🎯"
        case (false, true):  "Punkt für \(session.opponentName)"
        case (false, false): "Diesmal keiner richtig"
        }
    }

    // MARK: Logik

    private func choose(_ option: QuizOption) {
        guard pendingChoice == nil, !session.hasAnsweredCurrent else { return }
        pendingChoice = option.text
        UISelectionFeedbackGenerator().selectionChanged()
        Task {
            await session.submit(answer: option.text, isCorrect: option.isCorrect)
            // Bei Fehler wieder freigeben, sonst hält der Server-Stand die Wahl
            if session.myCurrentAnswer == nil && !session.hasAnsweredCurrent { pendingChoice = nil }
        }
    }

    /// Gleiche Reihenfolge der Antworten für beide Spieler (Seed = Match + Frage)
    private func prepareOptions() {
        guard let question = session.currentQuestion, optionsIndex != session.currentIndex else { return }
        optionsIndex = session.currentIndex
        pendingChoice = nil

        let seedBase = session.match?.id.uuidString.unicodeScalars.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1.value) } ?? 0
        var rng = SeededRandom(seed: seedBase &+ UInt64(session.currentIndex))
        let base = question.options.enumerated().map { index, text in
            QuizOption(text: text, isCorrect: index == question.correctAnswerIndex)
        }
        // Fisher-Yates mit festem Seed
        var shuffled = base
        for i in stride(from: shuffled.count - 1, to: 0, by: -1) {
            let j = min(Int(rng.next() * CGFloat(i + 1)), i)
            shuffled.swapAt(i, j)
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            options = shuffled
        }
    }
}
