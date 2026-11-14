//
//  LobbyHubView.swift
//  IOS - Quizzen
//
//  Einstieg in den Duell-Modus + Container, der je nach Zustand die
//  passende Ansicht zeigt (Code eingeben → Warteraum → Spiel →
//  Rundenergebnis → wieder Warteraum).
//

import SwiftUI

enum LobbyRoute: Hashable {
    case create
    case join
}

struct LobbyHubView: View {
    /// Eine Session für den ganzen Tab – korrekt als StateObject gehalten
    @StateObject private var session = LobbySession()
    @EnvironmentObject var router: AppRouter
    @State private var path: [LobbyRoute] = []
    @State private var abandonedNotice: String?
    /// Freund, der beim Erstellen eingeladen wird
    @State private var inviteTarget: Account?
    @State private var invitations: [LobbyInvite] = []
    @State private var declinedInvitations: Set<UUID> = []

    private var visibleInvitations: [LobbyInvite] { invitations.filter { !declinedInvitations.contains($0.lobby_id) } }

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
                // Kein Pausieren: Eine offene Lobby ohne laufende Session wurde
                // verlassen (App beendet/abgestürzt) und wird abgebrochen.
                guard path.isEmpty, session.lobby == nil else { return }
                await cancelAbandonedLobby()
                // Einladungen abfragen, solange der Hub sichtbar ist
                while !Task.isCancelled {
                    await loadInvitations()
                    try? await Task.sleep(for: .seconds(8))
                }
            }
            .onAppear(perform: consumeRouterInvite)
            .onChange(of: router.duelInvite) { _, _ in consumeRouterInvite() }
            .navigationDestination(for: LobbyRoute.self) { route in
                switch route {
                case .create: LobbyMatchView(session: session, mode: .create, invite: inviteTarget, path: $path)
                case .join:   LobbyMatchView(session: session, mode: .join, path: $path)
                }
            }
        }
        .onChange(of: path) { _, newPath in
            // Zurück im Hub → laufende Lobby sauber verlassen
            if newPath.isEmpty {
                inviteTarget = nil
                if session.lobby != nil { Task { await session.leave() } }
            }
        }
    }

    // MARK: - Einladungen

    /// „Zum Duell fordern" aus einem Profil: Lobby mit Einladung erstellen
    private func consumeRouterInvite() {
        guard let friend = router.duelInvite else { return }
        router.duelInvite = nil
        guard session.lobby == nil else { return }
        inviteTarget = friend
        path = [.create]
    }

    private func loadInvitations() async {
        let service = LobbyService()
        guard let invites = try? await service.fetchInvitations() else { return }
        withAnimation { invitations = invites }
    }

    private var invitationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Einladungen", systemImage: "envelope.badge.fill")
                .font(.headline)
            ForEach(visibleInvitations) { invite in
                HStack(spacing: 12) {
                    AvatarView(username: invite.inviter_username, url: invite.inviter_avatar_url, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "\(invite.inviter_username) fordert dich heraus"))
                            .font(.subheadline.weight(.semibold))
                        Text(invite.created_at.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation { _ = declinedInvitations.insert(invite.lobby_id) }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Ablehnen")
                    Button {
                        Task {
                            await session.joinLobby(code: invite.invite_code)
                            if session.lobby != nil { path = [.join] }
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
                Label("Bis zu 10 Personen", systemImage: "person.3.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                Text("Fordere deine Freunde heraus")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Eine Lobby, mehrere Runden, auch mit wechselndem Quiz.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.top, 8)
    }

    private func cancelAbandonedLobby() async {
        let service = LobbyService()
        guard let lobby = try? await service.fetchMyOpenLobby() else { return }
        log.info("Verwaiste Lobby gefunden: \(lobby.invite_code) status=\(lobby.status) erstellt=\(lobby.created_at)")
        do {
            try await service.leave(lobbyId: lobby.id)
            withAnimation {
                abandonedNotice = lobby.lobbyStatus == .playing
                    ? String(localized: "Deine letzte Runde wurde abgebrochen, weil du die Lobby verlassen hast.")
                    : String(localized: "Dein offener Warteraum wurde geschlossen.")
            }
        } catch {
            log.error("Verlassene Lobby konnte nicht abgebrochen werden: \(error.localizedDescription)")
        }
    }

    private var actionCards: some View {
        HStack(spacing: 12) {
            actionCard(title: String(localized: "Lobby erstellen"), subtitle: String(localized: "Code teilen"), icon: "plus", tint: .brand) {
                path.append(.create)
            }
            actionCard(title: String(localized: "Beitreten"), subtitle: String(localized: "Code eingeben"), icon: "number", tint: .purple) {
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
            step(1, String(localized: "Erstelle eine Lobby und teile den 6-stelligen Code – oder fordere jemanden direkt aus der Freundesliste heraus."))
            step(2, String(localized: "Bis zu 10 Personen können beitreten. Sobald mindestens zwei da sind, wählt der Host ein Quiz."))
            step(3, String(localized: "Ihr bekommt alle dieselben Fragen und seht nach jeder, wer richtig lag."))
            step(4, String(localized: "Nach der Runde geht's zurück in die Lobby – weiter geht's mit einer neuen Runde, auch mit einem anderen Quiz."))
            step(5, String(localized: "Kein Pausieren: Wer die App länger als 30 Sekunden verlässt, ist draußen."))
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

// MARK: - Lobby-Container

struct LobbyMatchView: View {
    enum Mode { case create, join }

    @ObservedObject var session: LobbySession
    let mode: Mode
    var invite: Account? = nil
    @Binding var path: [LobbyRoute]

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
                } else if session.phase != .idle {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Lobby verlassen", role: .destructive) {
                            Task { await session.leave(); path.removeAll() }
                        }
                    }
                }
            }
            .confirmationDialog("Runde wirklich aufgeben?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button("Aufgeben", role: .destructive) {
                    Task {
                        await session.leave()
                        path.removeAll()
                    }
                }
            } message: {
                Text("Du verlässt die Lobby und diese Runde zählt für dich als beendet.")
            }
            .task {
                if mode == .create, session.lobby == nil, !session.isBusy {
                    await session.createLobby(inviting: invite)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: session.phase)
            .animation(.easeInOut(duration: 0.25), value: session.finishedRoundNumber)
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
        if let round = session.finishedRoundNumber {
            LobbyRoundResultView(session: session, roundNumber: round)
        } else {
            switch session.phase {
            case .idle:
                if mode == .join {
                    LobbyJoinForm(session: session)
                } else if let error = session.errorMessage {
                    ContentUnavailableView {
                        Label("Lobby konnte nicht erstellt werden", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Erneut versuchen") { Task { await session.createLobby(inviting: invite) } }
                            .buttonStyle(.borderedProminent)
                            .tint(.brand)
                    }
                } else {
                    ProgressView(String(localized: "Lobby wird erstellt…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .room:
                LobbyRoomView(session: session)
            case .playing:
                LobbyGameView(session: session)
            }
        }
    }

    private var title: String {
        if session.finishedRoundNumber != nil { return String(localized: "Rundenergebnis") }
        switch session.phase {
        case .idle: return mode == .join ? String(localized: "Beitreten") : String(localized: "Lobby")
        case .room: return String(localized: "Warteraum")
        case .playing: return [session.quiz?.title, session.lobby?.settings?.label].compactMap { $0 }.joined(separator: " · ")
        }
    }
}
