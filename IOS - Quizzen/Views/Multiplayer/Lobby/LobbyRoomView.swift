//
//  LobbyRoomView.swift
//  IOS - Quizzen
//
//  Warteraum der Lobby: Mitgliederliste, Code teilen/Freund einladen,
//  und – nur für den Host – Quiz samt Einstellungen wählen und starten.
//  Wird auch zwischen zwei Runden angezeigt.
//

import SwiftUI

struct LobbyRoomView: View {
    @ObservedObject var session: LobbySession

    @State private var selectedQuiz: QuizDetail?
    @State private var duelSetup = DuelSetup()
    @State private var showInviteSheet = false

    private var selectedDefinition: QuizDefinition? {
        selectedQuiz.flatMap { QuizCatalog.definition(for: $0.id) }
    }

    /// Mit diesen Einstellungen gibt es genug Fragen
    private var canStart: Bool {
        guard let definition = selectedDefinition else { return false }
        return definition.availableCount(for: duelSetup.resolved(for: definition).config) > 0
    }

    private var hasPlayedBefore: Bool { session.lobby?.round_number ?? 0 > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                membersSection
                inviteCard

                if session.isHost {
                    quizPicker
                    if let definition = selectedDefinition {
                        PvPDuelSettingsPanel(definition: definition, setup: $duelSetup)
                            .id(definition.id)
                    }
                } else {
                    waitingHint
                }

                if let error = session.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            if session.isHost {
                startButton
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            LobbyInviteFriendsSheet(session: session)
        }
    }

    // MARK: Mitglieder

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "Mitspieler (\(session.activeMembers.count)/\(session.lobby?.max_players ?? 10))"))
                    .font(.headline)
                Spacer()
                Button {
                    showInviteSheet = true
                } label: {
                    Label("Einladen", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(session.activeMembers.count >= (session.lobby?.max_players ?? 10))
            }

            VStack(spacing: 8) {
                ForEach(session.activeMembers) { member in
                    memberRow(member)
                }
            }
        }
    }

    private func memberRow(_ member: LobbyMember) -> some View {
        let isMe = member.user_id == session.myUserId
        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(username: member.username, url: member.avatar_url, size: 44)
                if session.connection == .connected {
                    Circle()
                        .fill(session.isOnline(member.user_id) || isMe ? Color.green : Color.gray)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 2))
                }
            }
            HStack(spacing: 6) {
                Text(isMe ? String(localized: "\(member.username) (Du)") : member.username)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let country = member.country, !country.isEmpty {
                    FlagImage(name: country.lowercased(), width: 18, height: 12)
                }
                if member.is_host {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Host")
                }
            }
            Spacer(minLength: 0)
            if hasPlayedBefore {
                Label("\(member.total_correct)", systemImage: "star.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(10)
        .background(isMe ? Color.brand.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Code teilen

    private var inviteCard: some View {
        let code = session.lobby?.invite_code ?? "------"

        return VStack(spacing: 14) {
            Text("Code für weitere Mitspieler")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 6) {
                ForEach(Array(code.enumerated()), id: \.offset) { _, digit in
                    Text(String(digit))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 46)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Code \(code.map(String.init).joined(separator: " "))")

            HStack(spacing: 10) {
                ShareLink(item: String(localized: "Lass uns zusammen Quizzen! ⚔️ Öffne die App, tippe auf „Duell“ → „Beitreten“ und gib diesen Code ein: \(code)")) {
                    Label("Code teilen", systemImage: "square.and.arrow.up")
                }
                Button {
                    UIPasteboard.general.string = code
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Kopieren", systemImage: "doc.on.doc")
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.brand, Color.brandLight], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .shadow(color: Color.brand.opacity(0.3), radius: 14, y: 7)
    }

    private var waitingHint: some View {
        let hostName = session.members.first(where: \.is_host)?.username ?? String(localized: "Der Host")
        return VStack(spacing: 10) {
            Image(systemName: hasPlayedBefore ? "arrow.triangle.2.circlepath" : "hourglass")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(hasPlayedBefore
                 ? String(localized: "\(hostName) wählt die nächste Runde aus…")
                 : String(localized: "\(hostName) wählt gerade ein Quiz aus…"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: Quiz-Auswahl (Host)

    private var quizPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hasPlayedBefore ? String(localized: "Nächste Runde") : String(localized: "Wähle ein Quiz"))
                    .font(.title3.bold())
                Text("Danach wählst du die Schwierigkeit oder eigene Einstellungen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(QuizCatalog.categories) { category in
                Label(category.name, systemImage: category.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category.color)
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(category.quizzes) { definition in
                        quizCard(definition.baseQuiz)
                    }
                }
            }
        }
    }

    private func quizCard(_ quiz: QuizDetail) -> some View {
        let isSelected = selectedQuiz?.id == quiz.id
        return Button {
            withAnimation(.snappy) { selectedQuiz = quiz }
            if let definition = QuizCatalog.definition(for: quiz.id) { duelSetup.adapt(to: definition) }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                QuizCoverView(quiz: quiz)
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, Color.brand)
                                .padding(6)
                        }
                    }
                Text(quiz.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(quiz.questionCount) \(quiz.definition?.unit.plural ?? "Fragen")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.brandLight : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        let notEnough = session.activeMembers.count < 2

        return Button {
            guard let definition = selectedDefinition else { return }
            let resolved = duelSetup.resolved(for: definition)
            Task { await session.startRound(definition: definition, config: resolved.config,
                                            duration: resolved.duration, label: resolved.label) }
        } label: {
            Group {
                if session.isBusy {
                    ProgressView().tint(.white)
                } else if notEnough {
                    Text("Wartet noch auf Mitspieler…")
                } else if let quiz = selectedQuiz, let definition = selectedDefinition {
                    Label(canStart ? String(localized: "\(quiz.title) · \(duelSetup.resolved(for: definition).label) starten") : String(localized: "Keine passenden Fragen"),
                          systemImage: "play.fill")
                } else {
                    Text("Wähle zuerst ein Quiz")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(!canStart || notEnough ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(Color.brand),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canStart || notEnough || session.isBusy)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Freunde einladen

struct LobbyInviteFriendsSheet: View {
    @ObservedObject var session: LobbySession
    @EnvironmentObject var friendsViewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var invitedIds: Set<UUID> = []

    private var alreadyInLobby: Set<UUID> { Set(session.activeMembers.map(\.user_id)) }

    var body: some View {
        NavigationStack {
            Group {
                if friendsViewModel.friends.isEmpty {
                    ContentUnavailableView("Noch keine Freunde", systemImage: "person.2.slash")
                } else {
                    List(friendsViewModel.friends) { friend in
                        let account = friend.account.asAccount
                        let isMember = alreadyInLobby.contains(account.id)
                        let isInvited = invitedIds.contains(account.id)
                        HStack(spacing: 12) {
                            AvatarView(username: account.username, url: account.avatarUrl, size: 40)
                            Text(account.username).font(.subheadline.weight(.semibold))
                            Spacer()
                            if isMember {
                                Text("Schon dabei").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button(isInvited ? String(localized: "Gesendet") : String(localized: "Einladen")) {
                                    Task { await session.invite(friend: account) }
                                    invitedIds.insert(account.id)
                                }
                                .buttonStyle(.bordered)
                                .tint(.brand)
                                .disabled(isInvited)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Freund einladen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { if friendsViewModel.friends.isEmpty { await friendsViewModel.loadFriends() } }
        }
        .presentationDetents([.medium, .large])
    }
}
