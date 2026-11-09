//
//  FriendshipModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.07.26.
//

import Foundation

nonisolated enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case declined
}

nonisolated struct Friendship: Codable, Identifiable {
    let id: UUID
    let requesterId: UUID
    let addresseeId: UUID
    let status: FriendshipStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}


nonisolated struct FriendshipWithAccount: Codable, Identifiable {
    let id: UUID
    let requesterId: UUID
    let addresseeId: UUID
    let status: FriendshipStatus
    let createdAt: Date
    let requester: Account
    let addressee: Account

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case requester
        case addressee
    }
}
