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
        } catch {
            log.error("Fehler beim Laden der Anfragen: \(error.localizedDescription)")
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
