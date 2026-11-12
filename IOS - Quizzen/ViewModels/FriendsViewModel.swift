//
//  FriendsViewModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.07.26.
//

import Foundation
import Combine
import Supabase

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [FriendWithSince] = []
    @Published var incomingRequests: [Account] = []
    @Published var outgoingRequests: [Account] = []
    @Published var isLoadingFriends = false

    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        do {
            self.friends = try await supabase.fetchFriends()
        } catch {
            log.error("Fehler beim Laden der Freunde: \(error.localizedDescription)")
        }
    }

    func loadIncomingRequests() async {
        do {
            self.incomingRequests = try await supabase.fetchIncomingRequests()
                .filter { !BlockList.shared.isHidden($0.id) }
        } catch {
            log.error("Fehler beim Laden der Anfragen: \(error.localizedDescription)")
        }
    }

    func loadAll() async {
        async let friends: Void = loadFriends()
        async let incoming: Void = loadIncomingRequests()
        async let outgoing: Void = loadOutgoingRequests()
        _ = await (friends, incoming, outgoing)
    }

    // MARK: - Anfragen direkt aus der Liste beantworten

    /// IDs, für die gerade eine Aktion läuft (Buttons zeigen Ladeanzeige)
    @Published var busyIds: Set<UUID> = []

    func accept(_ account: Account) async -> Bool {
        await perform(on: account) { id in try await supabase.acceptFriendRequest(id: id) }
    }

    /// Ablehnen (eingehend) oder Zurückziehen (ausgehend)
    func remove(_ account: Account) async -> Bool {
        await perform(on: account) { id in try await supabase.removeFriendship(id: id) }
    }

    private func perform(on account: Account, _ action: (UUID) async throws -> Void) async -> Bool {
        busyIds.insert(account.id)
        defer { busyIds.remove(account.id) }
        do {
            guard let friendship = try await supabase.fetchFriendship(with: account.id) else { return false }
            try await action(friendship.id)
            await loadAll()
            return true
        } catch {
            log.error("Freundschaftsaktion fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    func loadOutgoingRequests() async {
        do {
            self.outgoingRequests = try await supabase.fetchOutgoingRequests()
        } catch {
            log.error("Fehler beim Laden der ausgehenden Anfragen: \(error.localizedDescription)")
        }
    }
}
