//
//  ProfileView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 20.06.26.
//

import Foundation
import SwiftUI

struct SocialLink: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let urlString: String

    var url: URL? {
            URL(string: urlString)
        }
}

struct ProfileView: View {
    @EnvironmentObject var viewModel: UserViewModel
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var friendsViewModel: FriendsViewModel

    @StateObject private var socialViewModel = SocialProfileEditViewModel()
    @State private var showMoreSheet = false

    private var stats: GlobalStats { statsManager.globalManager.stats }
    private var level: PlayerLevel { stats.level }

    private var appShareURL: URL { AppVersionService.appStoreURL }

    let socialLinks: [SocialLink] = [
        .init(name: "Website", imageName: "LogoWeb", urlString: "https://www.quizzen-app.de"),
        .init(name: "Instagram", imageName: "LogoInstagram", urlString: "https://www.instagram.com/quizzen.app"),
        .init(name: "WhatsApp", imageName: "LogoWhatsApp", urlString: "https://whatsapp.com/channel/0029Vb88Rot6RGJ8TvJKz90L")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ProfileHeroHeader(
                    username: viewModel.username,
                    avatarImage: viewModel.profileImage,
                    bannerId: socialViewModel.selectedBannerId,
                    level: level,
                    countryCode: viewModel.selectedOriginCode,
                    memberSince: stats.installDate
                ) {
                    HStack(spacing: 10) {
                        NavigationLink { SocialProfileEditView() } label: {
                            Label("Profil gestalten", systemImage: "paintbrush.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brand)

                        NavigationLink { EditProfilView() } label: {
                            Label("So sehen dich andere", systemImage: "eye")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                ProfileLevelCard(level: level)
                ProfileStatsGrid(stats: stats, friendsCount: friendsViewModel.friends.count,
                                 friendsDestination: FriendsListView())
                ProfileBadgeShowcase(badges: Badge.showcase(from: stats, selected: socialViewModel.selectedBadgeIdentifiers)) {
                    ProfileBadgeView()
                }
                menu
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Einstellungen")
            }
        }
        .sheet(isPresented: $showMoreSheet) {
            ProfileMoreView(appShareURL: appShareURL, socialLinks: socialLinks)
        }
        .task {
            await socialViewModel.load()
            if friendsViewModel.friends.isEmpty { await friendsViewModel.loadFriends() }
        }
    }

    // MARK: - Menü

    private var menu: some View {
        VStack(spacing: 0) {
            NavigationLink { ProfileStatsView() } label: {
                ProfileMenuRow(icon: "chart.bar.fill", tint: .blue, title: "Statistiken pro Quiz")
            }
            Divider().padding(.leading, 56)
            NavigationLink { AccountSettingsView() } label: {
                ProfileMenuRow(icon: "person.crop.circle", tint: .teal, title: "Account bearbeiten")
            }
            Divider().padding(.leading, 56)
            Button { showMoreSheet = true } label: {
                ProfileMenuRow(icon: "heart.fill", tint: .pink, title: "Mehr von Quizzen")
            }
            Divider().padding(.leading, 56)
            NavigationLink { SettingsView() } label: {
                ProfileMenuRow(icon: "gearshape.fill", tint: .gray, title: "Einstellungen")
            }
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

private struct ProfileMenuRow: View {
    let icon: String
    let tint: Color
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8))
            Text(title)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

// MARK: - Hilfs-Views
struct StatTile: View {
    let value: String
    let label: String
    var action: (() -> Void)? = nil
    private var destination: AnyView? = nil

    init(value: String, label: String, action: (() -> Void)? = nil) {
        self.value = value
        self.label = label
        self.action = action
        self.destination = nil
    }

    init<Destination: View>(
        value: String,
        label: String,
        @ViewBuilder destination: () -> Destination
    ) {
        self.value = value
        self.label = label
        self.action = nil
        self.destination = AnyView(destination())
    }

    var body: some View {
        if let destination {
            NavigationLink {
                destination
            } label: {
                content
            }
            .buttonStyle(StatBoxPressStyle())
        } else if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(StatBoxPressStyle())
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

/// Sorgt für ein dezentes Press-Feedback, wenn StatTile als Button genutzt wird.
private struct StatBoxPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    var tint: Color = .white.opacity(0.55)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(tint)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.06))
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ProfileView()
    }
    .environmentObject(StatsManager())
    .environmentObject(UserViewModel())
    .environmentObject(FriendsViewModel())
}
