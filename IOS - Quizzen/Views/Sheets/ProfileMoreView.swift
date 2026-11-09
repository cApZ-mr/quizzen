//
//  ProfileMoreView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.07.26.
//

import SwiftUI

/// „Mehr von Quizzen“: Bewerten, Einladen, Social Media, Kontakt, Rechtliches.
struct ProfileMoreView: View {
    let appShareURL: URL
    let socialLinks: [SocialLink]

    @Environment(\.openURL) private var openURL

    private var reviewURL: URL {
        URL(string: AppVersionService.appStoreURL.absoluteString + "?action=write-review") ?? appShareURL
    }

    private var supportMailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppLinks.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Quizzen – Support (Version \(appVersion))")]
        return components.url
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        return version
    }

    private let shareMessage = "Ich spiele gerade Quizzen – Flaggen, Hauptstädte, Harry Potter & mehr. Fordere mich zum Duell heraus! 🧠⚡️"

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    hero
                    socialSection
                    contactSection
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mehr von Quizzen")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Bewerten & Einladen

    private var hero: some View {
        VStack(spacing: 16) {
            Image("AppIconLight")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            VStack(spacing: 4) {
                Text("Gefällt dir Quizzen?")
                    .font(.title3.bold())
                Text("Eine Bewertung oder eine Einladung an Freunde hilft uns am meisten.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button {
                    openURL(reviewURL)
                } label: {
                    Label("Bewerten", systemImage: "star.fill")
                        .heroButtonStyle(background: AnyShapeStyle(Color.yellow.gradient), foreground: .black)
                }
                .buttonStyle(.plain)

                ShareLink(item: appShareURL,
                          subject: Text("Quizzen"),
                          message: Text(shareMessage)) {
                    Label("Einladen", systemImage: "square.and.arrow.up")
                        .heroButtonStyle(background: AnyShapeStyle(Color.brand.gradient), foreground: .white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.brand.opacity(0.35), Color(.secondarySystemGroupedBackground)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    // MARK: - Social Media

    @ViewBuilder
    private var socialSection: some View {
        if !socialLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Folge Quizzen")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(socialLinks) { link in
                        Button {
                            if let url = link.url { openURL(url) }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                socialIcon(for: link)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(subtitle(for: link))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                                    .padding(12)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(link.name) öffnen")
                    }
                }
            }
        }
    }

    // MARK: - Kontakt

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hilfe & Kontakt")
            VStack(spacing: 0) {
                NavigationLink { FeedbackView() } label: {
                    row(icon: "bubble.left.and.bubble.right.fill", tint: .blue,
                        title: "Feedback geben", subtitle: "Ideen, Lob oder Wünsche", chevron: "chevron.right")
                }
                Divider().padding(.leading, 60)
                NavigationLink { ReportView() } label: {
                    row(icon: "ant.fill", tint: .orange,
                        title: "Fehler melden", subtitle: "Etwas funktioniert nicht?", chevron: "chevron.right")
                }
                if let supportMailURL {
                    Divider().padding(.leading, 60)
                    Button { openURL(supportMailURL) } label: {
                        row(icon: "envelope.fill", tint: .green,
                            title: "E-Mail an den Support", subtitle: AppLinks.supportEmail, chevron: "arrow.up.right")
                    }
                }
            }
            .buttonStyle(.plain)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Fußzeile

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                if let url = AppLinks.privacyPolicy {
                    Link("Datenschutz", destination: url)
                }
                if let url = AppLinks.terms {
                    Link("Nutzungsbedingungen", destination: url)
                }
            }
            .font(.footnote)
            Text("Quizzen \(appVersion)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    // MARK: - Bausteine

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String, chevron: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: chevron)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func socialIcon(for link: SocialLink) -> some View {
        if link.name == "Website" {
            Image(systemName: "globe")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.brand.gradient, in: RoundedRectangle(cornerRadius: 10))
        } else {
            Image(link.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func subtitle(for link: SocialLink) -> String {
        switch link.name {
        case "Website": "Neuigkeiten & Infos"
        case "Instagram": "@quizzen.app"
        case "TikTok": "Kurze Quiz-Videos"
        case "WhatsApp": "Kanal beitreten"
        default: ""
        }
    }
}

private extension View {
    func heroButtonStyle(background: AnyShapeStyle, foreground: Color) -> some View {
        self
            .font(.subheadline.weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(background, in: Capsule())
    }
}
