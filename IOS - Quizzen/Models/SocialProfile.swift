//
//  SocialProfile.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 21.07.26.
//

import Foundation

nonisolated struct SocialProfile: Codable {
    let userId: UUID
    var bannerId: String?
    var selectedBadges: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case bannerId = "banner_id"
        case selectedBadges = "selected_badges"
    }
}
