//
//  ProfileBadgeDetailView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.07.26.
//

import Foundation
import SwiftUI

/// Abzeichen einer anderen Person
struct ProfileBadgeDetailView: View {
    let stats: GlobalStats?
    let username: String

    var body: some View {
        ProfileBadgeView(externalStats: stats ?? GlobalStats())
            .navigationTitle("Abzeichen von \(username)")
    }
}
