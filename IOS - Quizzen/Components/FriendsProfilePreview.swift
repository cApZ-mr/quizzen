//
//  FriendsProfilePreview.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 16.07.26.
//

import Foundation
import SwiftUI

struct FriendsProfilePreview: View {
    let friend: FriendWithSince
    private var account: AccountWithStats { friend.account }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: account.avatarUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.3))
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(account.username).fontWeight(.medium)

                Text("Freunde seit \(friend.friendsSince.formatted(date: .numeric , time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            }
        }
    }
}
