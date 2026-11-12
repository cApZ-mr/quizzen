//
//  SocialProfileEditViewModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 21.07.26.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
class SocialProfileEditViewModel: ObservableObject {
    @Published var selectedBannerId: String?
    @Published var selectedBadgeIdentifiers: [String] = []
    @Published var isSaving = false
    @Published var errorMessage: String?

    let maxBadges = 4

    func load() async {
        guard let myId = try? await supabase.auth.session.user.id else { return }
        do {
            if let profile = try await supabase.fetchSocialProfile(for: myId) {
                selectedBannerId = profile.bannerId
                selectedBadgeIdentifiers = profile.selectedBadges
            }
        } catch {
            log.error("Fehler beim Laden des Social-Profils: \(error.localizedDescription)")
        }
    }

    @Published var didSave = false

    func toggle(badge: Badge) {
        guard !badge.isLocked else { return }
        if let index = selectedBadgeIdentifiers.firstIndex(of: badge.identifier) {
            selectedBadgeIdentifiers.remove(at: index)
        } else {
            guard selectedBadgeIdentifiers.count < maxBadges else { return }
            selectedBadgeIdentifiers.append(badge.identifier)
        }
    }

    func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase.upsertMySocialProfile(bannerId: selectedBannerId, selectedBadges: selectedBadgeIdentifiers)
            didSave = true
        } catch {
            errorMessage = String(localized: "Konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }
}

struct SocialProfileEditView: View {
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SocialProfileEditViewModel()

    private var stats: GlobalStats { statsManager.globalManager.stats }
    private var level: PlayerLevel { stats.level }
    private var allBadges: [Badge] { Badge.make(from: stats) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                preview
                bannerSection
                badgeSection
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profil gestalten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.save()
                        if viewModel.didSave { dismiss() }
                    }
                } label: {
                    if viewModel.isSaving { ProgressView() } else { Text("Speichern").bold() }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .task { await viewModel.load() }
        .alert("Fehler", isPresented: $viewModel.errorMessage.isPresent()) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: Live-Vorschau

    private var preview: some View {
        VStack(spacing: 0) {
            ProfileBannerView(bannerId: viewModel.selectedBannerId)
                .frame(height: 120)
                .animation(.easeInOut, value: viewModel.selectedBannerId)
            HStack(spacing: 12) {
                AvatarView(username: userViewModel.username, url: nil, size: 64, image: userViewModel.profileImage)
                    .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 4))
                    .offset(y: -24)
                    .padding(.bottom, -24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(userViewModel.username).font(.headline)
                    Text("Level \(level.level) · \(level.title)")
                        .font(.caption)
                        .foregroundStyle(level.color)
                }
                Spacer()
                HStack(spacing: -10) {
                    ForEach(Badge.showcase(from: stats, selected: viewModel.selectedBadgeIdentifiers)) { badge in
                        BadgeMedalView(badge: badge, size: 34, showsLevel: false)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: Banner

    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(String(localized: "Banner"), subtitle: String(localized: "Weitere Banner schaltest du mit höherem Level frei."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(ProfileBanner.allCases) { banner in
                    bannerTile(banner)
                }
            }
            .padding(.horizontal)
        }
    }

    private func bannerTile(_ banner: ProfileBanner) -> some View {
        let isUnlocked = level.level >= banner.requiredLevel
        let isSelected = (ProfileBanner.from(id: viewModel.selectedBannerId) ?? .quiz) == banner

        return Button {
            guard isUnlocked else { return }
            withAnimation(.snappy) { viewModel.selectedBannerId = banner.id }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            ProfileBannerView(bannerId: banner.id)
                .frame(height: 84)
                .overlay {
                    if !isUnlocked {
                        ZStack {
                            Color.black.opacity(0.55)
                            Label("Ab Level \(banner.requiredLevel)", systemImage: "lock.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(banner.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, Color.brand)
                            .padding(6)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.brandLight : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(banner.displayName)\(isUnlocked ? "" : ", gesperrt bis Level \(banner.requiredLevel)")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Abzeichen

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Abzeichen-Vitrine",
                          subtitle: String(localized: "Wähle bis zu \(viewModel.maxBadges) freigeschaltete Abzeichen. Die Reihenfolge des Antippens bestimmt die Anzeige."))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(allBadges) { badge in
                    badgeCell(badge)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal)
        }
    }

    private func badgeCell(_ badge: Badge) -> some View {
        let position = viewModel.selectedBadgeIdentifiers.firstIndex(of: badge.identifier)

        return Button {
            withAnimation(.snappy) { viewModel.toggle(badge: badge) }
        } label: {
            VStack(spacing: 8) {
                BadgeMedalView(badge: badge, size: 72)
                    .padding(.bottom, 4)
                    .overlay(alignment: .topTrailing) {
                        if let position {
                            Text("\(position + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.brand, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .offset(x: 4, y: -4)
                        }
                    }
                Text(badge.name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity)
            .opacity(position == nil && viewModel.selectedBadgeIdentifiers.count >= viewModel.maxBadges ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(badge.isLocked)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}
