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
    @StateObject private var viewModel = ProfileViewModel()

    let account: Account

    @State private var confirmRemoveId: UUID?

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
        .task {
            await viewModel.load(for: account)
            await viewModel.loadFriendCount(for: account)
        }
    }

    // MARK: - Freundschafts-Aktion (beschriftet statt nur Icon)

    @ViewBuilder
    private var actionButton: some View {
        Group {
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
                Menu {
                    Button("Freundschaft beenden", role: .destructive) { confirmRemoveId = id }
                } label: {
                    Label("Befreundet", systemImage: "person.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(.green)
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
