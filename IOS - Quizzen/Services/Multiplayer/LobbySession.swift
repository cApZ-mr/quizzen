//
//  LobbySession.swift
//  IOS - Quizzen
//
//  Steuert eine Duell-Lobby (bis zu 10 Personen, mehrere Runden
//  hintereinander). Grundprinzip wie beim bisherigen 1-gegen-1-Duell:
//  Der Server ist die einzige Wahrheit. Die Session lädt regelmäßig den
//  kompletten Zustand (lobby_state) und leitet daraus alles ab. Realtime-
//  Events lösen nur ein sofortiges Neuladen aus – geht eins verloren, holt
//  das Polling den Stand spätestens nach 1–2 s nach.
//
//  Nach der letzten Frage einer Runde springt die Lobby serverseitig
//  zurück auf „offen" – die Session erkennt den Übergang (playing → open,
//  gleiche Rundennummer) und zeigt kurz das Rundenergebnis, bevor es
//  zurück in den Warteraum geht.
//

import Foundation
import Combine
import Supabase
import Realtime

@MainActor
final class LobbySession: ObservableObject {

    enum Phase: Equatable {
        case idle      // noch keine Lobby
        case room      // Warteraum: offen, zwischen den Runden
        case playing
    }

    enum ConnectionState { case idle, connecting, connected, reconnecting }

    /// Wie lange die Auflösung (richtige Antwort + Wahl der anderen) gezeigt wird
    static let revealDuration: TimeInterval = 2.5
    /// Wer länger im Hintergrund ist, gilt als ausgestiegen (kein Pausieren)
    static let maxBackgroundTime: TimeInterval = 30

    // MARK: Zustand vom Server
    @Published private(set) var lobby: Lobby?
    @Published private(set) var members: [LobbyMember] = []
    @Published private(set) var answers: [LobbyAnswer] = []
    @Published private(set) var myUserId: UUID?

    // MARK: Lokaler Zustand
    @Published private(set) var connection: ConnectionState = .idle
    @Published private var onlineUserIds: Set<String> = []
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    /// Gesetzt, sobald eine Runde gerade zu Ende gegangen ist; die View zeigt
    /// dann das Ergebnis, bis sie es per `dismissRoundResult()` schließt.
    @Published private(set) var finishedRoundNumber: Int?
    /// Server-korrigierte aktuelle Zeit (tickt für Timer-Anzeigen)
    @Published private(set) var now = Date()

    private let service = LobbyService()
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
    /// Letzter bekannter Status, um den Übergang „Runde gerade beendet" zu erkennen
    private var lastKnownStatus: Lobby.Status?
    private var lastKnownRound: Int?

    // MARK: - Abgeleitete Werte

    var phase: Phase {
        guard let lobby else { return .idle }
        return lobby.lobbyStatus == .playing ? .playing : .room
    }

    var isHost: Bool { lobby?.host_id == myUserId && myUserId != nil }

    var activeMembers: [LobbyMember] { members.filter(\.isActive) }
    /// Mitspieler ohne mich, aktiv zuerst, danach nach Gesamtpunkten sortiert
    var others: [LobbyMember] { activeMembers.filter { $0.user_id != myUserId } }
    var me: LobbyMember? { members.first { $0.user_id == myUserId } }

    func isOnline(_ userId: UUID) -> Bool { onlineUserIds.contains(userId.uuidString) }

    var quiz: QuizDetail? {
        guard let quizId = lobby?.quiz_id else { return nil }
        if cachedQuiz?.id != quizId {
            cachedQuiz = DataService.loadAllQuizzes().first { $0.id == quizId } ?? DataService.loadQuiz(from: quizId)
        }
        return cachedQuiz
    }

    var currentIndex: Int { lobby?.current_question_index ?? 0 }
    var totalQuestions: Int { lobby?.questionCount ?? 0 }

    func question(at index: Int) -> Question? {
        guard let quiz, let lobby, let order = lobby.question_order, index < order.count,
              order[index] < quiz.questions.count else { return nil }

        guard let settings = lobby.settings, let definition = QuizCatalog.definition(for: quiz.id),
              order[index] < definition.items.count else {
            return quiz.questions[order[index]]
        }
        if let cached = generatedQuestions[index], cachedLobbyId == lobby.id, cachedRound == lobby.round_number { return cached }
        if cachedLobbyId != lobby.id || cachedRound != lobby.round_number {
            generatedQuestions = [:]; cachedLobbyId = lobby.id; cachedRound = lobby.round_number
        }

        // Gleicher Startwert auf allen Geräten → identische Antworten
        var rng = SeededGenerator(seed: Self.seed(lobbyId: lobby.id, round: lobby.round_number, index: index))
        let question = definition.makeQuestion(for: definition.items[order[index]],
                                               answerCount: settings.answerCount,
                                               distractors: QuizConfig.Distractors(rawValue: settings.distractors) ?? .similar,
                                               using: &rng)
        generatedQuestions[index] = question
        return question
    }

    private var generatedQuestions: [Int: Question] = [:]
    private var cachedLobbyId: UUID?
    private var cachedRound: Int?

    /// Stabiler Startwert (nicht hashValue – der ist pro App-Start zufällig)
    nonisolated static func seed(lobbyId: UUID, round: Int, index: Int) -> UInt64 {
        lobbyId.uuidString.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
            &+ UInt64(round) &* 104729 &+ UInt64(index) &* 7919
    }

    var currentQuestion: Question? { question(at: currentIndex) }

    func answer(of userId: UUID?, at index: Int) -> LobbyAnswer? {
        guard let userId else { return nil }
        return answers.first { $0.user_id == userId && $0.question_index == index }
    }

    var myCurrentAnswer: LobbyAnswer? { answer(of: myUserId, at: currentIndex) }
    var hasAnsweredCurrent: Bool { myCurrentAnswer != nil || submittedIndices.contains(currentIndex) }
    /// Wer von den Mitspielenden (ohne mich) hat die aktuelle Frage schon beantwortet
    func othersAnswered(at index: Int) -> [LobbyMember] { others.filter { answer(of: $0.user_id, at: index) != nil } }

    /// Punkte NUR der laufenden Runde (für Scoreboard während des Spiels + Rundenergebnis)
    func roundScore(of userId: UUID) -> Int {
        answers.filter { answer in
            answer.user_id == userId && answer.is_correct
            && (phase != .playing || answer.question_index < currentIndex || isRevealing)
        }.count
    }

    var myRoundScore: Int { me.map { roundScore(of: $0.user_id) } ?? 0 }

    /// Zeitpunkt, ab dem die aktuelle Frage endet
    var questionDeadline: Date? {
        guard let start = lobby?.question_started_at else { return nil }
        return start.addingTimeInterval(TimeInterval(lobby?.duration ?? 20))
    }

    var remainingTime: TimeInterval {
        guard let deadline = questionDeadline else { return 0 }
        return max(0, deadline.timeIntervalSince(now))
    }

    /// Ich habe geantwortet und (alle aktiven Mitglieder haben auch geantwortet ODER die Zeit ist um)
    var isRevealing: Bool {
        guard phase == .playing, hasAnsweredCurrent else { return false }
        let allAnswered = activeMembers.allSatisfy { answer(of: $0.user_id, at: currentIndex) != nil }
        return allAnswered || remainingTime <= 0
    }

    // MARK: - Aktionen

    /// Eingeladener Freund (für die Anzeige im Warteraum, bevor er beigetreten ist)
    @Published private(set) var invitedFriend: Account?

    func createLobby(inviting friend: Account? = nil) async {
        invitedFriend = friend
        await run {
            let lobby = try await self.service.createLobby()
            try await self.attach(to: lobby)
            if let friend {
                try? await self.service.invite(lobbyId: lobby.id, friendId: friend.id)
            }
        }
    }

    func joinLobby(code: String) async {
        await run {
            let lobby = try await self.service.joinLobby(code: code)
            try await self.attach(to: lobby)
            await self.broadcastSync()
        }
    }

    func rejoin(_ lobby: Lobby) async {
        await run { try await self.attach(to: lobby) }
    }

    func invite(friend: Account) async {
        guard let lobby else { return }
        try? await service.invite(lobbyId: lobby.id, friendId: friend.id)
    }

    /// Startet eine neue Runde mit den gewählten Einstellungen (nur Host)
    func startRound(definition: QuizDefinition, config: QuizConfig, duration: Int, label: String) async {
        guard let lobby else { return }
        let poolIds = Set(definition.pool(for: config).map(\.question.id))
        let indices = definition.items.indices.filter { poolIds.contains(definition.items[$0].question.id) }
        let order = Array(indices.shuffled().prefix(max(1, config.questionCount)))
        let settings = DuelSettings(answerCount: config.answerCount, distractors: config.distractors.rawValue, label: label)
        await run {
            try await self.service.startRound(lobbyId: lobby.id, quizId: definition.id, questionOrder: order,
                                               duration: duration, settings: settings)
            await self.refresh()
            await self.broadcastSync()
        }
    }

    /// Antwort abgeben; `answer == nil` bedeutet „Zeit abgelaufen".
    func submit(answer: String?, isCorrect: Bool, silent: Bool = false) async {
        guard let lobby, phase == .playing else { return }
        let index = currentIndex
        guard !submittedIndices.contains(index) else { return }
        submittedIndices.insert(index)

        do {
            try await service.submitAnswer(lobbyId: lobby.id, questionIndex: index, answer: answer, isCorrect: isCorrect)
            await refresh()
            await broadcastSync()
        } catch {
            submittedIndices.remove(index)   // erneut versuchen erlauben
            if !silent { errorMessage = String(localized: "Antwort konnte nicht gesendet werden. Prüfe deine Verbindung.") }
            log.error("submit_lobby_answer: \(error.localizedDescription)")
        }
    }

    /// Runden-Ergebnis geschlossen → zurück in den Warteraum
    func dismissRoundResult() {
        finishedRoundNumber = nil
    }

    func leave() async {
        if let lobby {
            try? await service.leave(lobbyId: lobby.id)
            await broadcastSync()
        }
        await detach()
        reset()
    }

    // MARK: - App im Hintergrund

    func appDidEnterBackground() {
        guard phase != .idle else { return }
        backgroundedAt = Date()
    }

    /// Kurzes Wegschalten ist erlaubt; nach mehr als 30 s gilt man als ausgestiegen.
    func appDidBecomeActive() async {
        guard let since = backgroundedAt else { return }
        backgroundedAt = nil
        guard Date().timeIntervalSince(since) > Self.maxBackgroundTime else {
            await refresh()
            return
        }
        await leave()
    }

    func reset() {
        lobby = nil
        members = []
        answers = []
        errorMessage = nil
        onlineUserIds = []
        submittedIndices = []
        lastAdvanceAttempt = nil
        cachedQuiz = nil
        backgroundedAt = nil
        invitedFriend = nil
        connection = .idle
        finishedRoundNumber = nil
        lastKnownStatus = nil
        lastKnownRound = nil
    }

    // MARK: - Verbindung

    private func attach(to lobby: Lobby) async throws {
        await detach()
        submittedIndices = []
        myUserId = try await supabase.auth.session.user.id
        self.lobby = lobby
        connection = .connecting

        await subscribeRealtime(lobbyId: lobby.id)

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

    private func subscribeRealtime(lobbyId: UUID) async {
        let channel = supabase.channel("lobby-\(lobbyId.uuidString)")
        self.channel = channel

        let lobbyChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "lobbies",
                                                  filter: .eq("id", value: lobbyId.uuidString))
        let memberChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "lobby_members",
                                                   filter: .eq("lobby_id", value: lobbyId.uuidString))
        let answerChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "lobby_answers",
                                                   filter: .eq("lobby_id", value: lobbyId.uuidString))
        let syncHints = channel.broadcastStream(event: "sync")
        let presence = channel.presenceChange()

        backgroundTasks.append(Task { [weak self] in
            for await _ in lobbyChanges { await self?.refresh() }
        })
        backgroundTasks.append(Task { [weak self] in
            for await _ in memberChanges { await self?.refresh() }
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
                for state in (try? action.decodeJoins(as: LobbyPresenceState.self)) ?? [] { self.onlineUserIds.insert(state.userId) }
                for state in (try? action.decodeLeaves(as: LobbyPresenceState.self)) ?? [] { self.onlineUserIds.remove(state.userId) }
            }
        })

        do {
            try await channel.subscribeWithError()
            try await channel.track(LobbyPresenceState(userId: myUserId?.uuidString ?? ""))
            connection = .connected
        } catch {
            // Kein Abbruch: Polling hält den Zustand trotzdem synchron
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
        guard let lobbyId = lobby?.id else { return }
        // Nie parallel laden; Anfragen während eines Ladevorgangs werden gebündelt
        if isRefreshing { refreshQueued = true; return }
        isRefreshing = true
        defer { isRefreshing = false }

        repeat {
            refreshQueued = false
            do {
                let state = try await service.fetchState(lobbyId: lobbyId)
                guard lobby?.id == lobbyId else { return }   // inzwischen verlassen
                apply(state)
                if connection == .reconnecting { connection = channel?.status == .subscribed ? .connected : .reconnecting }
            } catch {
                let mapped = LobbyError.from(error)
                if case .serverNotReady = mapped { errorMessage = mapped.errorDescription }
                if connection == .connected { connection = .reconnecting }
                log.error("lobby_state: \(error.localizedDescription)")
            }
        } while refreshQueued
    }

    private func apply(_ state: LobbyStateResponse) {
        clockOffset = state.server_time.timeIntervalSince(Date())
        now = Date().addingTimeInterval(clockOffset)

        let previousIndex = lobby?.current_question_index

        // Übergang „Runde gerade beendet" erkennen: war aktiv „playing", ist jetzt
        // „open", gleiche Rundennummer wie zuletzt gesehen.
        if lastKnownStatus == .playing, state.lobby.lobbyStatus == .open,
           lastKnownRound == state.lobby.round_number {
            finishedRoundNumber = state.lobby.round_number
        }
        lastKnownStatus = state.lobby.lobbyStatus
        lastKnownRound = state.lobby.round_number

        if lobby != state.lobby { lobby = state.lobby }
        if members != state.members { members = state.members }
        if answers != state.answers { answers = state.answers }

        if previousIndex != state.lobby.current_question_index {
            lastAdvanceAttempt = nil
            lastTimeoutSubmit = nil
            errorMessage = nil
        }
        // Eigene Antworten, die der Server kennt, gelten als abgegeben
        for answer in state.answers where answer.user_id == myUserId {
            submittedIndices.insert(answer.question_index)
        }
    }

    // MARK: - Taktgeber

    private func tick() async {
        now = Date().addingTimeInterval(clockOffset)
        guard phase == .playing, let lobby else { return }
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

        // 2) Nach der Auflösung weiterschalten. Das darf jedes Mitglied anstoßen –
        //    der Server führt es genau einmal aus.
        guard isRevealing else { return }
        let revealStart: Date = {
            let answerTimes = activeMembers.compactMap { answer(of: $0.user_id, at: index)?.answered_at }
            return answerTimes.max() ?? questionDeadline ?? now
        }()
        let readyToAdvance = now.timeIntervalSince(revealStart) >= Self.revealDuration
        let throttled = lastAdvanceAttempt.map { $0.index == index && now.timeIntervalSince($0.at) < 1.5 } ?? false

        if readyToAdvance && !throttled {
            lastAdvanceAttempt = (index, now)
            do {
                try await service.advance(lobbyId: lobby.id, fromIndex: index)
                await refresh()
                await broadcastSync()
            } catch {
                log.error("advance_lobby: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helfer

    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch {
            errorMessage = LobbyError.from(error).errorDescription
        }
    }
}
