//
//  Account.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 06.07.26.
//

import Foundation

nonisolated struct Account: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String
    let avatarUrl: String?
    let country: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
        case country
        case createdAt = "created_at"
    }
}

nonisolated struct AccountStats: Codable, Hashable {
    let currentStreak: Int?
    let bestStreak: Int?
    let totalAnswers: Int?
    let correctAnswers: Int?
    let falseAnswers: Int?
    let quizzesPlayed: Int?
    let playTime: Double?

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case bestStreak = "best_streak"
        case totalAnswers = "total_answers"
        case correctAnswers = "correct_answers"
        case falseAnswers = "false_answers"
        case quizzesPlayed = "quizzes_played"
        case playTime = "play_time"
    }
}

nonisolated struct AccountWithStats: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String
    let avatarUrl: String?
    let country: String?
    let createdAt: Date
    let stats: AccountStats?

    enum CodingKeys: String, CodingKey {
        case id, username, country
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case stats = "user_stats"
    }

    var asAccount: Account {
        Account(id: id, username: username, avatarUrl: avatarUrl, country: country, createdAt: createdAt)
    }
}
