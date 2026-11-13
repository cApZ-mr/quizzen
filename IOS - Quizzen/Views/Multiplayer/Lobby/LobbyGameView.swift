//
//  LobbyGameView.swift
//  IOS - Quizzen
//
//  Spielansicht einer Lobby-Runde (bis zu 10 Personen). Alle Zustände
//  kommen aus der LobbySession (Server-Wahrheit) – die View hält nur die
//  Antwort-Reihenfolge.
//

import Foundation
import SwiftUI

struct LobbyGameView: View {
    @ObservedObject var session: LobbySession

    @State private var options: [QuizOption] = []
    @State private var optionsIndex: Int = -1
    @State private var pendingChoice: String?

    var body: some View {
        VStack(spacing: 14) {
            playersStrip
            timerAndProgress

            if let question = session.currentQuestion {
                questionCard(question)
                Spacer(minLength: 0)
                optionsList
                statusLine
            } else {
                Spacer()
                ProgressView(String(localized: "Frage wird geladen…"))
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .onAppear(perform: prepareOptions)
        .onChange(of: session.currentIndex) { _, _ in prepareOptions() }
        .onChange(of: session.lobby?.quiz_id) { _, _ in prepareOptions() }
        .onChange(of: session.isRevealing) { _, revealing in
            guard revealing else { return }
            let correct = session.myCurrentAnswer?.is_correct ?? false
            UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        }
    }

    // MARK: Kopf: Mitspielende, Punkte, Timer

    /// Horizontaler Streifen aller Mitspielenden, nach Rundenpunkten sortiert, ich zuerst bei Gleichstand
    private var playersStrip: some View {
        let sorted = session.activeMembers.sorted { a, b in
            let sa = session.roundScore(of: a.user_id), sb = session.roundScore(of: b.user_id)
            if sa != sb { return sa > sb }
            return a.user_id == session.myUserId
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(sorted) { member in
                    playerBadge(member)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.top, 8)
    }

    private func playerBadge(_ member: LobbyMember) -> some View {
        let isMe = member.user_id == session.myUserId
        let answered = session.answer(of: member.user_id, at: session.currentIndex) != nil

        return VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(username: member.username, url: member.avatar_url, size: isMe ? 46 : 38)
                    .overlay(isMe ? Circle().stroke(Color.brandLight, lineWidth: 2) : nil)
                if answered && !session.isRevealing {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white, .green)
                        .offset(x: 3, y: 3)
                        .transition(.scale)
                } else if !isMe && session.connection == .connected && !session.isOnline(member.user_id) {
                    Image(systemName: "wifi.slash")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.gray, in: Circle())
                        .offset(x: 3, y: 3)
                }
            }
            Text(isMe ? String(localized: "Du") : member.username)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: 60)
            Text("\(session.roundScore(of: member.user_id))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isMe ? Color.brandLight : .secondary)
                .contentTransition(.numericText())
                .animation(.spring, value: session.roundScore(of: member.user_id))
        }
        .animation(.spring(duration: 0.3), value: answered)
    }

    private var timerAndProgress: some View {
        VStack(spacing: 10) {
            timerRing
            progressDots
        }
    }

    private var timerRing: some View {
        let duration = Double(session.lobby?.duration ?? 20)
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
                    .font(.system(.caption2, weight: .semibold))
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

    private func dotColor(index: Int, answer: LobbyAnswer?) -> Color {
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
                .font(.system(.title3, design: .rounded, weight: .semibold))
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

    /// Mitspielende (ohne mich), die während der Auflösung diese Antwort gewählt haben
    private func othersWhoChose(_ text: String) -> [LobbyMember] {
        guard session.isRevealing else { return [] }
        return session.others.filter { session.answer(of: $0.user_id, at: session.currentIndex)?.answer == text }
    }

    private func optionLabel(_ option: QuizOption) -> some View {
        let myChoice = session.myCurrentAnswer?.answer ?? pendingChoice
        let isMine = myChoice == option.text
        let pickers = othersWhoChose(option.text)
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
                .font(.system(.body, weight: .medium))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !pickers.isEmpty {
                HStack(spacing: -10) {
                    ForEach(pickers.prefix(4)) { picker in
                        AvatarView(username: picker.username, url: picker.avatar_url, size: 24)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    }
                    if pickers.count > 4 {
                        Text("+\(pickers.count - 4)")
                            .font(.caption2.weight(.bold))
                            .frame(width: 24, height: 24)
                            .background(.white.opacity(0.3), in: Circle())
                    }
                }
                .accessibilityLabel("\(pickers.map(\.username).joined(separator: ", ")) haben das gewählt")
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
        .opacity(revealing && !option.isCorrect && !isMine && pickers.isEmpty ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: revealing)
    }

    private var statusLine: some View {
        let othersAnswered = session.othersAnswered(at: session.currentIndex)

        return Group {
            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if session.isRevealing {
                let me = session.myCurrentAnswer?.is_correct ?? false
                Text(me ? String(localized: "Richtig! 🎯") : String(localized: "Diesmal nicht – weiter geht's"))
                    .foregroundStyle(me ? .green : .secondary)
            } else if session.hasAnsweredCurrent || pendingChoice != nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(othersAnswered.count == session.others.count && !session.others.isEmpty
                         ? String(localized: "Auflösung kommt…")
                         : String(localized: "Noch \(session.others.count - othersAnswered.count) warten…"))
                }
                .foregroundStyle(.secondary)
            } else if !othersAnswered.isEmpty {
                Label(String(localized: "\(othersAnswered.count) haben schon geantwortet"), systemImage: "bolt.fill")
                    .foregroundStyle(.orange)
            } else {
                Text(" ")
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(height: 22)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
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

    /// Gleiche Reihenfolge der Antworten für alle (Seed = Lobby + Runde + Frage)
    private func prepareOptions() {
        guard let question = session.currentQuestion, optionsIndex != session.currentIndex else { return }
        optionsIndex = session.currentIndex
        pendingChoice = nil

        let seedBase = session.lobby?.id.uuidString.unicodeScalars.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1.value) } ?? 0
        var rng = SeededRandom(seed: seedBase &+ UInt64(session.lobby?.round_number ?? 0) &* 997 &+ UInt64(session.currentIndex))
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
