//
//  MainView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 14.05.26.
//

import SwiftUI
import Supabase

struct MainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var statsManager: StatsManager

    @State private var splashScreen = true
    @State private var showUpdateAlert = false

    var body: some View {
        Group {
            if DebugLaunch.skipLogin {
                MainAppContainer()
            } else if splashScreen || authViewModel.isLoading {
                SplashScreen()
            } else {
                if authViewModel.isLoggedIn {
                    MainAppContainer()
                } else {
                    WelcomeView()
                }
            }
        }
        .task(id: authViewModel.isLoggedIn) {
            guard authViewModel.isLoggedIn else { return }
            await clearDataIfAccountChanged()
            await userViewModel.loadProfile()
            await statsManager.syncFromServer()
            // „Dabei seit“ = Registrierung, nicht Installation auf diesem Gerät
            if let created = userViewModel.accountCreatedAt {
                if created < statsManager.globalManager.stats.installDate {
                    statsManager.globalManager.stats.installDate = created
                }
                // Unmögliche Streaks (länger als das Konto alt ist) korrigieren
                if statsManager.globalManager.clampStreaks(accountCreated: created) {
                    await supabase.syncUserStats(statsManager.globalManager.stats)
                }
            }
        }
        .task {
            // Splash höchstens 0,5 s zeigen, egal wie lange der Versions-Check braucht.
            async let updateAvailable = AppVersionService.isUpdateAvailable()
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation { splashScreen = false }
            if await updateAvailable {
                showUpdateAlert = true
            }
        }
        .alert("Update verfügbar", isPresented: $showUpdateAlert) {
            Button("Später", role: .cancel) {}
            Button("Jetzt aktualisieren") {
                UIApplication.shared.open(AppVersionService.appStoreURL)
            }
        } message: {
            Text("Eine neuere Version ist im App Store verfügbar.")
        }
    }
}

// MARK: - Accountwechsel

extension MainView {
    /// Lokale Daten (Quiz-Fortschritt, Profil) gehören zu einem Account.
    /// Sie werden NUR gelöscht, wenn sich ein anderer Account anmeldet –
    /// nicht bei jedem „abgemeldet“-Ereignis (z. B. kurzer Sitzungsverlust),
    /// sonst ginge der nur lokal gespeicherte Fortschritt verloren.
    func clearDataIfAccountChanged() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }
        let key = "lastSignedInUserId"
        let previous = UserDefaults.standard.string(forKey: key)
        if let previous, previous != userId {
            log.notice("Anderer Account angemeldet – lokale Daten werden zurückgesetzt")
            statsManager.resetAll()
            userViewModel.clearLocalData()
        }
        UserDefaults.standard.set(userId, forKey: key)
    }
}

// MARK: - Debug-Start (nur DEBUG-Builds)
enum DebugLaunch {
    /// `-skipLogin` als Startargument: App ohne Login öffnen, um UI im
    /// Simulator zu prüfen. In Release-Builds immer `false`.
    static var skipLogin: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-skipLogin")
        #else
        false
        #endif
    }

    /// `-debugSearch <Begriff>`: Suchfeld vorbelegen (UI-Test im Simulator)
    static var initialSearch: String {
        #if DEBUG
        UserDefaults.standard.string(forKey: "debugSearch") ?? ""
        #else
        ""
        #endif
    }
}

// MARK: - Version checken
enum AppVersionService {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6771577989")!

    /// Fragt die App-Store-Version ab. Liefert nur `true`, wenn die Store-Version
    /// wirklich NEUER ist (z. B. 1.10.0 > 1.9.3), nicht bei Dev-/TestFlight-Builds.
    static func isUpdateAvailable() async -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else { return false }

        struct LookupResponse: Decodable {
            struct Result: Decodable { let version: String }
            let results: [Result]
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let storeVersion = response.results.first?.version else { return false }
            return isVersion(storeVersion, newerThan: currentVersion)
        } catch {
            log.info("Versions-Check fehlgeschlagen: \(error.localizedDescription)")
            return false
        }
    }

    nonisolated static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }
}

// MARK: - Preview
#Preview {
    MainView()
}
