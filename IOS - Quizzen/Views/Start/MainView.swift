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
    @State private var requiredUpdate: StoreRelease?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let requiredUpdate {
                // Pflicht-Update: ersetzt die ganze App (auch offene Sheets)
                ForceUpdateView(release: requiredUpdate)
                    .transition(.opacity)
            } else if DebugLaunch.skipLogin {
                MainAppContainer()
            } else if splashScreen || authViewModel.isLoading {
                SplashScreen()
                    .transition(.opacity.combined(with: .scale(scale: 1.12)))
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
            // Splash so lange zeigen, bis die Animation durch ist (≈ 1,4 s),
            // egal wie lange der Versions-Check braucht.
            async let release = AppVersionService.requiredUpdate()
            try? await Task.sleep(for: .milliseconds(1450))
            withAnimation(.easeInOut(duration: 0.35)) { splashScreen = false }
            requiredUpdate = await release
        }
        .onChange(of: scenePhase) { _, phase in
            // Beim Zurückkehren in die App erneut prüfen – so lässt sich die
            // Sperre nicht durch Hintergrund/Vordergrund umgehen.
            guard phase == .active, !splashScreen else { return }
            Task { requiredUpdate = await AppVersionService.requiredUpdate() }
        }
        .animation(.easeInOut, value: requiredUpdate)
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

// MARK: - Preview
#Preview {
    MainView()
}
