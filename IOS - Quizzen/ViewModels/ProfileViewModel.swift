//
//  ProfileViewModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 15.07.26.
//

import Foundation
import Combine
import Supabase

enum FriendshipState: Equatable {
    case loading
    case none
    case pendingOutgoing(friendshipId: UUID)
    case pendingIncoming(friendshipId: UUID)
    case friends(friendshipId: UUID)
    case isMe
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var stats: AccountStats?
    @Published var friendshipState: FriendshipState = .loading
    @Published var isPerformingAction = false
    @Published var socialProfile: SocialProfile?
    
    @Published var friendCount: Int = 0
    @Published var errorMessage: String?
    @Published private(set) var isLoading = true


    func load(for account: Account) async {
        defer { isLoading = false }
        async let statsResult = try? supabase.fetchStats(for: account.id)
        async let friendshipResult = try? supabase.fetchFriendship(with: account.id)
        async let socialProfileResult = try? await supabase.fetchSocialProfile(for: account.id)

        self.stats = await statsResult ?? nil
        self.socialProfile = await socialProfileResult ?? nil

        guard let myId = try? await supabase.auth.session.user.id else { return }
        if myId == account.id {
            self.friendshipState = .isMe
            return
        }

        if let friendship = await friendshipResult ?? nil {
            switch friendship.status {
            case .accepted:
                friendshipState = .friends(friendshipId: friendship.id)
            case .pending:
                friendshipState = friendship.requesterId == myId
                    ? .pendingOutgoing(friendshipId: friendship.id)
                    : .pendingIncoming(friendshipId: friendship.id)
            case .declined:
                friendshipState = .none
            }
        } else {
            friendshipState = .none
        }
    }

    func sendRequest(to account: Account) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await supabase.sendFriendRequest(to: account.id)
            await load(for: account)
        } catch {
            log.error("Fehler beim Senden der Anfrage: \(error.localizedDescription)")
            errorMessage = "Freundschaftsanfrage konnte nicht gesendet werden. Bitte versuch es erneut."
        }
    }

    func acceptRequest(friendshipId: UUID, account: Account) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await supabase.acceptFriendRequest(id: friendshipId)
            await load(for: account)
        } catch {
            log.error("Fehler beim Annehmen: \(error.localizedDescription)")
            errorMessage = "Anfrage konnte nicht angenommen werden. Bitte versuch es erneut."
        }
    }

    func removeOrDecline(friendshipId: UUID, account: Account) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await supabase.removeFriendship(id: friendshipId)
            await load(for: account)
        } catch {
            log.error("Fehler beim Entfernen: \(error.localizedDescription)")
            errorMessage = "Aktion konnte nicht ausgeführt werden. Bitte versuch es erneut."
        }
    }
    
    func loadFriendCount(for account: Account) async {
        do {
            friendCount = try await supabase.fetchFriendCount(for: account.id)
        } catch {
            log.error("Fehler beim Laden der Freundesanzahl: \(error.localizedDescription)")
        }
    }
}
