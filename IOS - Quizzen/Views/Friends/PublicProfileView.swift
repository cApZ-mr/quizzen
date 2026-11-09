//
//  PublicProfileView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.07.26.
//

import Foundation
import SwiftUI

struct PublicProfileView: View {
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var friendsViewModel: FriendsViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @ObservedObject private var blockList = BlockList.shared

    let account: Account

    @State private var confirmRemoveId: UUID?
    @State private var showReport = false
    @State private var confirmBlock = false
    @State private var moderationNotice: String?

    private var isBlocked: Bool { blockList.isHidden(account.id) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ProfileSummaryView(
                username: account.username,
                createdAt: account.createdAt,
                avatarUrl: account.avatarUrl,
                bannerId: viewModel.socialProfile?.bannerId,
                country: account.country,
                stats: globalStatsFromAccount,
                friendsCount: viewModel.friendCount,
                selectedBadges: viewModel.socialProfile?.selectedBadges ?? [],
                isLoading: viewModel.isLoading,
                actionContent: AnyView(actionButton)
            )
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Fehler", isPresented: $viewModel.errorMessage.isPresent()) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("Freundschaft mit \(account.username) beenden?",
                            isPresented: Binding(get: { confirmRemoveId != nil }, set: { if !$0 { confirmRemoveId = nil } }),
                            titleVisibility: .visible) {
            Button("Freundschaft beenden", role: .destructive) {
                if let id = confirmRemoveId {
                    Task { await viewModel.removeOrDecline(friendshipId: id, account: account) }
                }
            }
        }
        .toolbar {
            if viewModel.friendshipState != .isMe && viewModel.friendshipState != .loading {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReport = true
                        } label: {
                            Label("\(account.username) melden", systemImage: "exclamationmark.bubble")
                        }
                        if isBlocked {
                            Button {
                                Task { await unblock() }
                            } label: {
                                Label("Blockierung aufheben", systemImage: "hand.raised.slash")
                            }
                        } else {
                            Button(role: .destructive) {
                                confirmBlock = true
                            } label: {
                                Label("Blockieren", systemImage: "hand.raised.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Weitere Optionen")
                }
            }
        }
        .confirmationDialog("\(account.username) blockieren?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Blockieren", role: .destructive) { Task { await block() } }
        } message: {
            Text("Eure Freundschaft und offene Anfragen werden beendet. Ihr seht euch nicht mehr in der Suche und könnt euch nicht mehr zum Duell einladen. Du kannst das in den Einstellungen wieder aufheben.")
        }
        .sheet(isPresented: $showReport) {
            ReportUserSheet(account: account) { blockToo in
                moderationNotice = "Danke für deine Meldung. Wir sehen sie uns an."
                if blockToo { Task { await block() } }
            }
        }
        .alert("Erledigt", isPresented: $moderationNotice.isPresent()) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(moderationNotice ?? "")
        }
        .task {
            await viewModel.load(for: account)
            await viewModel.loadFriendCount(for: account)
        }
        .onChange(of: viewModel.friendshipState) { old, new in
            guard old != .loading, new != .loading else { return }
            Task {
                await viewModel.loadFriendCount(for: account)
                await friendsViewModel.loadFriends()
                await friendsViewModel.loadIncomingRequests()
                await friendsViewModel.loadOutgoingRequests()
            }
        }
    }

    private func block() async {
        do {
            try await blockList.block(account.id)
            await viewModel.load(for: account)
        } catch {
            log.error("Blockieren fehlgeschlagen: \(error.localizedDescription)")
            viewModel.errorMessage = "Blockieren hat nicht geklappt. Bitte versuch es erneut."
        }
    }

    private func unblock() async {
        do {
            try await blockList.unblock(account.id)
            await viewModel.load(for: account)
        } catch {
            log.error("Entblocken fehlgeschlagen: \(error.localizedDescription)")
            viewModel.errorMessage = "Das hat nicht geklappt. Bitte versuch es erneut."
        }
    }

    // MARK: - Freundschafts-Aktion (beschriftet statt nur Icon)

    @ViewBuilder
    private var actionButton: some View {
        Group {
            if isBlocked && viewModel.friendshipState != .isMe {
                Button {
                    Task { await unblock() }
                } label: {
                    Label("Blockiert – aufheben", systemImage: "hand.raised.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
            switch viewModel.friendshipState {
            case .loading:
                ProgressView().frame(height: 34)
            case .isMe:
                Label("Das bist du", systemImage: "person.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .none:
                Button {
                    Task { await viewModel.sendRequest(to: account) }
                } label: {
                    Label("Als Freund hinzufügen", systemImage: "person.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.brand)
            case .pendingOutgoing(let id):
                Menu {
                    Button("Anfrage zurückziehen", role: .destructive) {
                        Task { await viewModel.removeOrDecline(friendshipId: id, account: account) }
                    }
                } label: {
                    Label("Anfrage gesendet", systemImage: "clock")
                }
                .buttonStyle(.bordered)
            case .pendingIncoming(let id):
                HStack(spacing: 10) {
                    Button {
                        Task { await viewModel.acceptRequest(friendshipId: id, account: account) }
                    } label: {
                        Label("Annehmen", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    Button(role: .destructive) {
                        Task { await viewModel.removeOrDecline(friendshipId: id, account: account) }
                    } label: {
                        Label("Ablehnen", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            case .friends(let id):
                HStack(spacing: 10) {
                    Button {
                        router.challenge(account)
                    } label: {
                        Label("Zum Duell fordern", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brand)
                    Menu {
                        Button("Freundschaft beenden", role: .destructive) { confirmRemoveId = id }
                    } label: {
                        Label("Befreundet", systemImage: "person.2.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .accessibilityLabel("Befreundet – Optionen")
                }
            }
            }
        }
        .font(.subheadline.weight(.semibold))
        .disabled(viewModel.isPerformingAction)
    }

    private var globalStatsFromAccount: GlobalStats? {
        guard let accountStats = viewModel.stats else { return nil }
        return GlobalStats(from: accountStats)
    }
}
