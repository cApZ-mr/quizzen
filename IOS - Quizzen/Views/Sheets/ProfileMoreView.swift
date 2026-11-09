//
//  ProfileMoreView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.07.26.
//

import SwiftUI

/// Ein einziges Popup-Sheet mit allen "Rund um die App"-Aktionen:
/// Bewerten, Einladen, Social Media. Alles direkt sichtbar, keine
/// weiteren verschachtelten Sheets/Views mehr – gleicher Card-Stil
/// wie zuvor in SocialMediaSheet.
struct ProfileMoreView: View {
    let appShareURL: URL
    let socialLinks: [SocialLink]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var appStoreReviewURL: URL {
        URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review") ?? appShareURL
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Link(destination: appStoreReviewURL) {
                        actionRow(
                            icon: "star.fill",
                            tint: .yellow,
                            title: "Bewerte Quizzen",
                            subtitle: "Schreib uns eine Bewertung im App Store"
                        )
                    }
                    .buttonStyle(.plain)

                    ShareLink(
                        item: appShareURL,
                        subject: Text("Quizzen App"),
                        message: Text("Schau dir Quizzen an – die App für spaßige Quizze! \n->")
                    ) {
                        actionRow(
                            icon: "square.and.arrow.up",
                            tint: .blue,
                            title: "Zu Quizzen einladen",
                            subtitle: "Teile die App mit Freunden"
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(socialLinks) { link in
                        Button {
                            if let url = link.url {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Image(link.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(subtitle(for: link))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mehr von Quizzen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func actionRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(.title3, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func subtitle(for link: SocialLink) -> String {
        switch link.name {
        case "Website": return "Besuche unsere Webseite"
        case "Instagram": return "Folge uns auf Instagram"
        case "TikTok": return "Schau unsere Videos"
        case "WhatsApp": return "Tritt unserem Kanal bei"
        default: return ""
        }
    }
}
