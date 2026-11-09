//
//  PvPLobbyView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 12.07.26.
//
//  Einstieg in den Duell-Modus + Container, der je nach Spielphase
//  die passende Ansicht zeigt (Warteraum → Lobby → Spiel → Ergebnis).
//

import SwiftUI

enum PvPRoute: Hashable {
    case create
    case join
}

struct PvPLobbyView: View {
    /// Eine Session für den ganzen Tab – korrekt als StateObject gehalten
    @StateObject private var session = PvPSession()
    @EnvironmentObject var router: AppRouter
    @State private var path: [PvPRoute] = []
    @State private var abandonedNotice: String?
    /// Freund, der beim Erstellen eingeladen wird
    @State private var inviteTarget: Account?
    @State private var invitations: [Match] = []
    @State private var invitationHosts: [UUID: Account] = [:]
    @State private var declinedInvitations: Set<UUID> = []

    private var visibleInvitations: [Match] { invitations.filter { !declinedInvitations.contains($0.id) } }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    if let abandonedNotice {
                        Label(abandonedNotice, systemImage: "flag.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                            .transition(.opacity)
                    }
                    if !visibleInvitations.isEmpty {
                        invitationsSection
                    }
                    actionCards
                    howItWorks
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Duell")
            .task(id: path.isEmpty) {
                // Kein Pausieren: Ein offenes Duell ohne laufende Session wurde
                // verlassen (App beendet/abgestürzt) und wird abgebrochen.
                guard path.isEmpty, session.match == nil else { return }
                await cancelAbandonedMatch()
                // Einladungen abfragen, solange der Hub sichtbar ist
                while !Task.isCancelled {
                    await loadInvitations()
                    try? await Task.sleep(for: .seconds(8))
                }
            }
            .onAppear(perform: consumeRouterInvite)
            .onChange(of: router.duelInvite) { _, _ in consumeRouterInvite() }
            .navigationDestination(for: PvPRoute.self) { route in
                switch route {
                case .create: PvPMatchView(session: session, mode: .create, invite: inviteTarget, path: $path)
                case .join:   PvPMatchView(session: session, mode: .join, path: $path)
                }
            }
        }
        #if DEBUG
        .onAppear {
            if let demo = UserDefaults.standard.string(forKey: "duelDemo"), session.match == nil {
                session.loadDemo(finished: demo == "result")
                path = [.create]
            } else if UserDefaults.standard.string(forKey: "debugJoinCode") != nil, path.isEmpty {
                path = [.join]
            }
        }
        #endif
        .onChange(of: path) { _, newPath in
            // Zurück im Hub → laufendes Match sauber verlassen
            if newPath.isEmpty {
                inviteTarget = nil
                if session.match != nil { Task { await session.leave() } }
            }
        }
    }

    // MARK: - Einladungen

    /// „Zum Duell fordern“ aus einem Profil: Duell mit Einladung erstellen
    private func consumeRouterInvite() {
        guard let friend = router.duelInvite else { return }
        router.duelInvite = nil
        guard session.match == nil else { return }
        inviteTarget = friend
        path = [.create]
    }

    private func loadInvitations() async {
        let service = PvPLobbyService()
        guard var matches = try? await service.fetchInvitations() else { return }
        matches.removeAll { BlockList.shared.isHidden($0.host_id) }
        let missing = Set(matches.map(\.host_id)).filter { invitationHosts[$0] == nil }
        if !missing.isEmpty, let accounts = try? await service.fetchAccounts(ids: Array(missing)) {
            for account in accounts { invitationHosts[account.id] = account }
        }
        withAnimation { invitations = matches }
    }

    private var invitationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Einladungen", systemImage: "envelope.badge.fill")
                .font(.headline)
            ForEach(visibleInvitations) { match in
                let host = invitationHosts[match.host_id]
                HStack(spacing: 12) {
                    AvatarView(username: host?.username ?? "?", url: host?.avatarUrl, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(host?.username ?? "Ein Freund") fordert dich heraus")
                            .font(.subheadline.weight(.semibold))
                        Text(match.created_at.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation { _ = declinedInvitations.insert(match.id) }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Ablehnen")
                    Button {
                        Task {
                            await session.joinMatch(code: match.invite_code)
                            if session.match != nil { path = [.join] }
                        }
                    } label: {
                        Text("Annehmen").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brand)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandLight.opacity(0.6), lineWidth: 1.5))
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            ProfileBannerView(bannerId: ProfileBanner.neon.id)
                .frame(height: 180)
            VStack(alignment: .leading, spacing: 6) {
                Label("1 gegen 1", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                Text("Fordere deine Freunde heraus")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Gleiche Fragen, gleiche Zeit – wer weiß mehr?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.top, 8)
    }

    private func cancelAbandonedMatch() async {
        let service = PvPLobbyService()
        guard let match = try? await service.fetchMyOpenMatch() else { return }
        log.info("Verwaistes Duell gefunden: \(match.invite_code) status=\(match.status) erstellt=\(match.created_at)")
        do {
            try await service.leave(matchId: match.id)
            withAnimation {
                abandonedNotice = match.matchStatus == .active
                    ? "Dein letztes Duell wurde abgebrochen, weil du es verlassen hast."
                    : "Dein offener Warteraum wurde geschlossen."
            }
        } catch {
            log.error("Verlassenes Duell konnte nicht abgebrochen werden: \(error.localizedDescription)")
        }
    }

    private var actionCards: some View {
        HStack(spacing: 12) {
            actionCard(title: "Duell erstellen", subtitle: "Code teilen", icon: "plus", tint: .brand) {
                path.append(.create)
            }
            actionCard(title: "Beitreten", subtitle: "Code eingeben", icon: "number", tint: .purple) {
                path.append(.join)
            }
        }
    }

    private func actionCard(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("So funktioniert's").font(.headline)
            step(1, "Erstelle ein Duell und teile den 6-stelligen Code – oder fordere jemanden direkt aus der Freundesliste heraus.")
            step(2, "Sobald dein Gegenüber beigetreten ist, wählst du ein Quiz aus.")
            step(3, "Du bestimmst Schwierigkeit, Fragenzahl und Zeit – ihr bekommt beide dieselben Fragen und seht nach jeder, wer richtig lag.")
            step(4, "Kein Pausieren: Wer die App länger als 30 Sekunden verlässt, gibt auf.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.brand, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Match-Container

struct PvPMatchView: View {
    enum Mode { case create, join }

    @ObservedObject var session: PvPSession
    let mode: Mode
    var invite: Account? = nil
    @Binding var path: [PvPRoute]

    @State private var confirmLeave = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title)
            .navigationBarBackButtonHidden(session.phase == .playing)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                if session.phase == .playing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Aufgeben", role: .destructive) { confirmLeave = true }
                    }
                }
            }
            .confirmationDialog("Duell wirklich aufgeben?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button("Aufgeben", role: .destructive) {
                    Task {
                        await session.leave()
                        path.removeAll()
                    }
                }
            } message: {
                Text("\(session.opponentName) gewinnt dann automatisch. Ein Duell lässt sich nicht pausieren.")
            }
            .task {
                if mode == .create, session.match == nil, !session.isBusy {
                    await session.createMatch(inviting: invite)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: session.phase)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background: session.appDidEnterBackground()
                case .active:     Task { await session.appDidBecomeActive() }
                default:          break
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .idle:
            if mode == .join {
                PvPJoinForm(session: session)
            } else if let error = session.errorMessage {
                ContentUnavailableView {
                    Label("Duell konnte nicht erstellt werden", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Erneut versuchen") { Task { await session.createMatch(inviting: invite) } }
                        .buttonStyle(.borderedProminent)
                        .tint(.brand)
                }
            } else {
                ProgressView("Duell wird erstellt…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .waitingForOpponent, .lobby:
            PvPWaitingRoom(session: session)
        case .playing:
            PvPGameView(session: session)
        case .finished, .cancelled:
            PvPResultView(session: session) {
                Task {
                    await session.leave()
                    path.removeAll()
                }
            }
        }
    }

    private var title: String {
        switch session.phase {
        case .idle: mode == .join ? "Beitreten" : "Duell"
        case .waitingForOpponent, .lobby: "Warteraum"
        case .playing:
            [session.quiz?.title, session.match?.settings?.label].compactMap { $0 }.joined(separator: " · ")
        case .finished, .cancelled: "Ergebnis"
        }
    }
}

// MARK: - Spieler-Kopf (Du vs. Gegner)

struct PvPPlayersHeader: View {
    @ObservedObject var session: PvPSession
    var showsScores = false
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            player(session.me, fallback: "Du", score: session.myScore, isMe: true)
            Spacer(minLength: 0)
            Text("VS")
                .font(.system(compact ? .subheadline : .title3, design: .rounded).weight(.black))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            player(session.opponent, fallback: session.opponentId == nil ? "Wartet…" : "Gegner",
                   score: session.opponentScore, isMe: false)
        }
    }

    private func player(_ account: Account?, fallback: String, score: Int, isMe: Bool) -> some View {
        let size: CGFloat = compact ? 44 : 72
        let isPresent = isMe || session.opponentId != nil

        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                if isPresent {
                    AvatarView(username: account?.username ?? fallback, url: account?.avatarUrl, size: size)
                } else {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.secondary)
                        .frame(width: size, height: size)
                        .overlay(Image(systemName: "person.fill.questionmark").foregroundStyle(.secondary))
                }
                if !isMe && isPresent && session.connection == .connected {
                    Circle()
                        .fill(session.opponentOnline ? Color.green : Color.gray)
                        .frame(width: size * 0.24, height: size * 0.24)
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 2))
                        .accessibilityLabel(session.opponentOnline ? "online" : "offline")
                }
            }
            Text(isMe ? "Du" : (account?.username ?? fallback))
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(1)
            if showsScores {
                Text("\(score)")
                    .font(.system(compact ? .title3 : .title, design: .rounded).weight(.bold))
                    .contentTransition(.numericText())
                    .foregroundStyle(isMe ? Color.brandLight : .primary)
            }
        }
        .frame(width: compact ? 90 : 110)
    }
}
