//
//  PvPSession.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 11.07.26.
//
//  Steuert ein Duell. Grundprinzip: Der Server ist die einzige Wahrheit.
//  Die Session lädt regelmäßig den kompletten Zustand (match_state) und
//  leitet daraus alles ab (Phase, Punkte, wer geantwortet hat, Timer).
//  Realtime-Events und Broadcasts lösen nur ein sofortiges Neuladen aus –
//  geht eins verloren, holt das Polling den Stand spätestens nach 1–2 s nach.
//

import Foundation
import Combine
import Supabase
import Realtime

/// Deterministischer Zufallsgenerator (SplitMix64): gleicher Startwert →
/// gleiche Folge auf allen Geräten.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

nonisolated struct PvPPresenceState: Codable {
    let userId: String
}

@MainActor
final class PvPSession: ObservableObject {

    enum Phase: Equatable {
        case idle               // noch kein Match
        case waitingForOpponent // Host wartet auf Gast
        case lobby              // beide da, Host wählt Quiz
        case playing
        case finished
        case cancelled
    }

    enum ConnectionState { case idle, connecting, connected, reconnecting }

    /// Wie lange die Auflösung (richtige Antwort + Gegner-Wahl) gezeigt wird
    static let revealDuration: TimeInterval = 2.5
    /// Wer länger im Hintergrund ist, gibt auf (kein Pausieren)
    static let maxBackgroundTime: TimeInterval = 30

    // MARK: Zustand vom Server
    @Published private(set) var match: Match?
    @Published private(set) var answers: [MatchAnswer] = []
    @Published private(set) var myUserId: UUID?
    @Published private(set) var profiles: [UUID: Account] = [:]

    // MARK: Lokaler Zustand
    @Published private(set) var connection: ConnectionState = .idle
    @Published private var onlineUserIds: Set<String> = []
    var opponentOnline: Bool { opponentId.map { onlineUserIds.contains($0.uuidString) } ?? false }
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    /// Server-korrigierte aktuelle Zeit (tickt für Timer-Anzeigen)
    @Published private(set) var now = Date()

    private let service = PvPLobbyService()
    private var channel: RealtimeChannelV2?
    private var backgroundTasks: [Task<Void, Never>] = []
    private var clockOffset: TimeInterval = 0
    private var isRefreshing = false
    private var refreshQueued = false
    private var submittedIndices: Set<Int> = []
    private var lastAdvanceAttempt: (index: Int, at: Date)?
    private var lastTimeoutSubmit: (index: Int, at: Date)?
    private var cachedQuiz: QuizDetail?
    private var backgroundedAt: Date?

    // MARK: - Abgeleitete Werte

    var phase: Phase {
        guard let match else { return .idle }
        switch match.matchStatus {
        case .waiting:   return match.guest_id == nil ? .waitingForOpponent : .lobby
        case .active:    return .playing
        case .finished:  return .finished
        case .cancelled: return .cancelled
        }
    }

    var isHost: Bool { match?.host_id == myUserId && myUserId != nil }

    var opponentId: UUID? {
        guard let match else { return nil }
        return isHost ? match.guest_id : match.host_id
    }

    var me: Account? { myUserId.flatMap { profiles[$0] } }
    var opponent: Account? { opponentId.flatMap { profiles[$0] } }
    var opponentName: String { opponent?.username ?? "Gegner" }

    var quiz: QuizDetail? {
        guard let quizId = match?.quiz_id else { return nil }
        if cachedQuiz?.id != quizId {
            cachedQuiz = DataService.loadAllQuizzes().first { $0.id == quizId } ?? DataService.loadQuiz(from: quizId)
        }
        return cachedQuiz
    }

    var currentIndex: Int { match?.current_question_index ?? 0 }
    var totalQuestions: Int { match?.questionCount ?? 0 }

    func question(at index: Int) -> Question? {
        guard let quiz, let match, let order = match.question_order, index < order.count,
              order[index] < quiz.questions.count else { return nil }

        // Ohne Einstellungen: handverlesene Antworten wie im Quiz
        guard let settings = match.settings, let definition = QuizCatalog.definition(for: quiz.id),
              order[index] < definition.items.count else {
            return quiz.questions[order[index]]
        }
        if let cached = generatedQuestions[index], cachedMatchId == match.id { return cached }
        if cachedMatchId != match.id { generatedQuestions = [:]; cachedMatchId = match.id }

        // Gleicher Startwert auf beiden Geräten → identische Antworten
        var rng = SeededGenerator(seed: Self.seed(matchId: match.id, index: index))
        let question = definition.makeQuestion(for: definition.items[order[index]],
                                               answerCount: settings.answerCount,
                                               distractors: QuizConfig.Distractors(rawValue: settings.distractors) ?? .similar,
                                               using: &rng)
        generatedQuestions[index] = question
        return question
    }

    private var generatedQuestions: [Int: Question] = [:]
    private var cachedMatchId: UUID?

    /// Stabiler Startwert (nicht hashValue – der ist pro App-Start zufällig)
    nonisolated static func seed(matchId: UUID, index: Int) -> UInt64 {
        matchId.uuidString.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
            &+ UInt64(index) &* 7919
    }

    var currentQuestion: Question? { question(at: currentIndex) }

    func answer(of userId: UUID?, at index: Int) -> MatchAnswer? {
        guard let userId else { return nil }
        return answers.first { $0.user_id == userId && $0.question_index == index }
    }

    var myCurrentAnswer: MatchAnswer? { answer(of: myUserId, at: currentIndex) }
    var opponentCurrentAnswer: MatchAnswer? { answer(of: opponentId, at: currentIndex) }
    var hasAnsweredCurrent: Bool { myCurrentAnswer != nil || submittedIndices.contains(currentIndex) }

    var myScore: Int { visibleScore(of: myUserId) }
    var opponentScore: Int { visibleScore(of: opponentId) }

    /// Punkte der laufenden Frage erst nach der Auflösung zeigen (Spannung)
    private func visibleScore(of userId: UUID?) -> Int {
        answers.filter { answer in
            answer.user_id == userId && answer.is_correct
            && (phase != .playing || answer.question_index < currentIndex || isRevealing)
        }.count
    }

    /// Zeitpunkt, ab dem die aktuelle Frage endet
    var questionDeadline: Date? {
        guard let start = match?.question_started_at else { return nil }
        return start.addingTimeInterval(TimeInterval(match?.duration ?? 20))
    }

    var remainingTime: TimeInterval {
        guard let deadline = questionDeadline else { return 0 }
        return max(0, deadline.timeIntervalSince(now))
    }

    /// Beide haben geantwortet oder die Zeit ist abgelaufen → Lösung zeigen
    var isRevealing: Bool {
        guard phase == .playing else { return false }
        return (myCurrentAnswer != nil && opponentCurrentAnswer != nil) || remainingTime <= 0
    }

    var didIWin: Bool? {
        if phase == .cancelled, let leftBy = match?.left_by {
            return leftBy != myUserId
        }
        guard phase == .finished else { return nil }
        if myScore == opponentScore { return nil }
        return myScore > opponentScore
    }

    // MARK: - Aktionen

    func createMatch() async {
        await run {
            let match = try await self.service.createMatch()
            try await self.attach(to: match)
        }
    }

    func joinMatch(code: String) async {
        await run {
            let match = try await self.service.joinMatch(code: code)
            try await self.attach(to: match)
            await self.broadcastSync()
        }
    }

    /// Startet das Duell mit den gewählten Einstellungen (nur Host)
    func start(definition: QuizDefinition, config: QuizConfig, duration: Int, label: String) async {
        guard let match else { return }
        // Fragen aus dem gefilterten Pool, als Indizes im Gesamt-Quiz
        let poolIds = Set(definition.pool(for: config).map(\.question.id))
        let indices = definition.items.indices.filter { poolIds.contains(definition.items[$0].question.id) }
        let order = Array(indices.shuffled().prefix(max(1, config.questionCount)))
        let settings = DuelSettings(answerCount: config.answerCount, distractors: config.distractors.rawValue, label: label)
        await run {
            try await self.service.startMatch(matchId: match.id, quizId: definition.id, questionOrder: order,
                                              duration: duration, settings: settings)
            await self.refresh()
            await self.broadcastSync()
        }
    }

    /// Antwort abgeben; `answer == nil` bedeutet „Zeit abgelaufen“.
    func submit(answer: String?, isCorrect: Bool, silent: Bool = false) async {
        guard let match, phase == .playing else { return }
        let index = currentIndex
        guard !submittedIndices.contains(index) else { return }
        submittedIndices.insert(index)

        do {
            try await service.submitAnswer(matchId: match.id, questionIndex: index, answer: answer, isCorrect: isCorrect)
            await refresh()
            await broadcastSync()
        } catch {
            submittedIndices.remove(index)   // erneut versuchen erlauben
            if !silent { errorMessage = "Antwort konnte nicht gesendet werden. Prüfe deine Verbindung." }
            log.error("submit_answer: \(error.localizedDescription)")
        }
    }

    func leave() async {
        if let match, phase != .finished, phase != .cancelled {
            try? await service.leave(matchId: match.id)
            await broadcastSync()
        }
        await detach()
        reset()
    }

    // MARK: - App im Hintergrund

    func appDidEnterBackground() {
        guard phase == .playing || phase == .lobby || phase == .waitingForOpponent else { return }
        backgroundedAt = Date()
    }

    /// Kurzes Wegschalten ist erlaubt; nach mehr als 30 s gilt das Duell als aufgegeben.
    func appDidBecomeActive() async {
        guard let since = backgroundedAt else { return }
        backgroundedAt = nil
        guard Date().timeIntervalSince(since) > Self.maxBackgroundTime else {
            await refresh()
            return
        }
        await giveUp()
    }

    /// Aufgeben, aber Ergebnis anzeigen (statt direkt zurück in den Hub)
    func giveUp() async {
        guard let match, phase != .finished, phase != .cancelled else { return }
        do {
            try await service.leave(matchId: match.id)
            await refresh()
            await broadcastSync()
        } catch {
            errorMessage = "Duell konnte nicht beendet werden."
        }
    }

    func reset() {
        match = nil
        answers = []
        profiles = [:]
        errorMessage = nil
        onlineUserIds = []
        submittedIndices = []
        lastAdvanceAttempt = nil
        cachedQuiz = nil
        backgroundedAt = nil
        connection = .idle
    }

    // MARK: - Verbindung

    private func attach(to match: Match) async throws {
        await detach()
        submittedIndices = []
        myUserId = try await supabase.auth.session.user.id
        self.match = match
        connection = .connecting

        await subscribeRealtime(matchId: match.id)

        // Polling als Sicherheitsnetz: schneller während des Spiels
        backgroundTasks.append(Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval: Duration = self.phase == .playing ? .seconds(1) : .seconds(2)
                try? await Task.sleep(for: interval)
                await self.refresh()
            }
        })

        // Uhr für Timer + automatische Schritte (Zeitablauf, Weiterschalten)
        backgroundTasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                await self?.tick()
            }
        })

        await refresh()
    }

    private func subscribeRealtime(matchId: UUID) async {
        let channel = supabase.channel("duel-\(matchId.uuidString)")
        self.channel = channel

        let matchChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "matches",
                                                  filter: .eq("id", value: matchId.uuidString))
        let answerChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "match_answers",
                                                   filter: .eq("match_id", value: matchId.uuidString))
        let syncHints = channel.broadcastStream(event: "sync")
        let presence = channel.presenceChange()

        backgroundTasks.append(Task { [weak self] in
            for await _ in matchChanges { await self?.refresh() }
        })
        backgroundTasks.append(Task { [weak self] in
            for await _ in answerChanges { await self?.refresh() }
        })
        backgroundTasks.append(Task { [weak self] in
            for await _ in syncHints { await self?.refresh() }
        })
        backgroundTasks.append(Task { [weak self] in
            for await action in presence {
                guard let self else { return }
                for state in (try? action.decodeJoins(as: PvPPresenceState.self)) ?? [] { self.onlineUserIds.insert(state.userId) }
                for state in (try? action.decodeLeaves(as: PvPPresenceState.self)) ?? [] { self.onlineUserIds.remove(state.userId) }
            }
        })

        do {
            try await channel.subscribeWithError()
            try await channel.track(PvPPresenceState(userId: myUserId?.uuidString ?? ""))
            connection = .connected
        } catch {
            // Kein Abbruch: Polling hält das Spiel trotzdem synchron
            connection = .reconnecting
            log.notice("Realtime nicht verfügbar, nutze Polling: \(error.localizedDescription)")
        }
    }

    private func detach() async {
        backgroundTasks.forEach { $0.cancel() }
        backgroundTasks.removeAll()
        if let channel {
            await supabase.removeChannel(channel)
        }
        channel = nil
    }

    private func broadcastSync() async {
        guard let channel, channel.status == .subscribed else { return }
        await channel.broadcast(event: "sync", message: [:])
    }

    // MARK: - Zustand laden

    func refresh() async {
        guard let matchId = match?.id else { return }
        // Nie parallel laden; Anfragen während eines Ladevorgangs werden gebündelt
        if isRefreshing { refreshQueued = true; return }
        isRefreshing = true
        defer { isRefreshing = false }

        repeat {
            refreshQueued = false
            do {
                let state = try await service.fetchState(matchId: matchId)
                guard match?.id == matchId else { return }   // inzwischen verlassen
                apply(state)
                if connection == .reconnecting { connection = channel?.status == .subscribed ? .connected : .reconnecting }
            } catch {
                let mapped = PvPLobbyError.from(error)
                if case .serverNotReady = mapped { errorMessage = mapped.errorDescription }
                if connection == .connected { connection = .reconnecting }
                log.error("match_state: \(error.localizedDescription)")
            }
        } while refreshQueued
    }

    private func apply(_ state: MatchState) {
        clockOffset = state.server_time.timeIntervalSince(Date())
        now = Date().addingTimeInterval(clockOffset)

        let previousIndex = match?.current_question_index
        if match != state.match { match = state.match }
        if answers != state.answers { answers = state.answers }

        if previousIndex != state.match.current_question_index {
            lastAdvanceAttempt = nil
            lastTimeoutSubmit = nil
            errorMessage = nil
        }
        // Eigene Antworten, die der Server kennt, gelten als abgegeben
        for answer in state.answers where answer.user_id == myUserId {
            submittedIndices.insert(answer.question_index)
        }

        Task { await loadProfilesIfNeeded() }
    }

    private func loadProfilesIfNeeded() async {
        guard let match else { return }
        let ids = [match.host_id, match.guest_id].compactMap { $0 }.filter { profiles[$0] == nil }
        guard !ids.isEmpty, let accounts = try? await service.fetchAccounts(ids: ids) else { return }
        for account in accounts { profiles[account.id] = account }
    }

    // MARK: - Taktgeber

    private func tick() async {
        now = Date().addingTimeInterval(clockOffset)
        guard phase == .playing, let match else { return }
        let index = currentIndex

        // 1) Zeit abgelaufen, aber noch nicht geantwortet → leere Antwort senden
        //    (höchstens alle 2 s versuchen; ein Fehler blockiert NICHT Schritt 2)
        if remainingTime <= 0 && !hasAnsweredCurrent {
            let recentlyTried = lastTimeoutSubmit.map { $0.index == index && now.timeIntervalSince($0.at) < 2 } ?? false
            if !recentlyTried {
                lastTimeoutSubmit = (index, now)
                await submit(answer: nil, isCorrect: false, silent: true)
            }
        }

        // 2) Nach der Auflösung weiterschalten. Beide Geräte dürfen das –
        //    der Server führt es genau einmal aus.
        guard isRevealing else { return }
        let revealStart: Date = {
            if let mine = myCurrentAnswer?.answered_at, let theirs = opponentCurrentAnswer?.answered_at {
                return max(mine, theirs)
            }
            return questionDeadline ?? now
        }()
        let readyToAdvance = now.timeIntervalSince(revealStart) >= Self.revealDuration
        let throttled = lastAdvanceAttempt.map { $0.index == index && now.timeIntervalSince($0.at) < 1.5 } ?? false

        if readyToAdvance && !throttled {
            lastAdvanceAttempt = (index, now)
            do {
                try await service.advance(matchId: match.id, fromIndex: index)
                await refresh()
                await broadcastSync()
            } catch {
                log.error("advance_match: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Debug-Demo (ohne Netzwerk, nur für UI-Prüfung im Simulator)

    #if DEBUG
    func loadDemo(finished: Bool) {
        let me = UUID(), other = UUID()
        myUserId = me
        profiles = [me: Account(id: me, username: "Du", avatarUrl: nil, country: "de", createdAt: .now),
                    other: Account(id: other, username: "Claudia", avatarUrl: nil, country: "de", createdAt: .now)]
        let current = finished ? 9 : 3
        match = Match(id: UUID(), invite_code: "482913", host_id: me, guest_id: other,
                      status: finished ? "finished" : "active", quiz_id: "FlagsEurope",
                      question_order: Array(0..<10), current_question_index: current,
                      host_score: 0, guest_score: 0, created_at: .now,
                      question_started_at: Date().addingTimeInterval(-7), question_duration: 20)
        let q = DataService.loadQuiz(from: "FlagsEurope")
        func answer(_ user: UUID, _ index: Int, correct: Bool) -> MatchAnswer {
            let question = q?.questions[index]
            let text = correct ? question?.options[question!.correctAnswerIndex] : question?.options.first { $0 != question?.options[question!.correctAnswerIndex] }
            return MatchAnswer(user_id: user, question_index: index, answer: text, is_correct: correct, answered_at: .now)
        }
        let upTo = finished ? 10 : current
        answers = (0..<upTo).flatMap { i in [answer(me, i, correct: i % 3 != 1), answer(other, i, correct: i % 2 == 0)] }
        if !finished { answers.append(answer(other, current, correct: true)) }
        now = Date()
    }
    #endif

    // MARK: - Helfer

    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            errorMessage = PvPLobbyError.from(error).errorDescription
        }
    }
}
