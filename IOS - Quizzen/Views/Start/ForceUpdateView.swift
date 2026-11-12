//
//  ForceUpdateView.swift
//  IOS - Quizzen
//

import SwiftUI

/// Sperrbildschirm, wenn im App Store eine neuere Version liegt.
/// Lässt sich nicht schließen – nur „Jetzt aktualisieren“ führt weiter.
struct ForceUpdateView: View {
    let release: StoreRelease

    @Environment(\.openURL) private var openURL
    @State private var appeared = false

    private var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.brand.opacity(0.45), Color(.systemBackground)],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 20)

                ZStack(alignment: .bottomTrailing) {
                    Image("AppIconLight")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 38, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.brand)
                        .background(Circle().fill(Color(.systemBackground)).padding(2))
                        .offset(x: 10, y: 10)
                }
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Update erforderlich")
                        .font(.largeTitle.bold())
                    Text("Version \(release.version) ist da. Bitte aktualisiere Quizzen, um weiterzuspielen.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    versionPill(installedVersion, label: String(localized: "Installiert"), highlighted: false)
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.tertiary)
                    versionPill(release.version, label: String(localized: "Neu"), highlighted: true)
                }

                if let notes = release.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Neu in dieser Version", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                }

                Spacer(minLength: 20)

                Button {
                    openURL(AppVersionService.appStoreURL)
                } label: {
                    Label("Jetzt aktualisieren", systemImage: "arrow.down.app.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brand.gradient, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) { appeared = true }
        }
    }

    private func versionPill(_ version: String, label: String, highlighted: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(highlighted ? .white.opacity(0.85) : .secondary)
            Text(version)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(highlighted ? .white : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(highlighted ? AnyShapeStyle(Color.brand.gradient) : AnyShapeStyle(Color(.secondarySystemBackground)),
                    in: Capsule())
    }
}

#Preview {
    ForceUpdateView(release: StoreRelease(version: "2.0.3", releaseNotes: "• Neue Quizze\n• Fehlerbehebungen"))
}
