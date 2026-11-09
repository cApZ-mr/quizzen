//
//  StreakReminder.swift
//  IOS - Quizzen
//
//  Lokale Erinnerung um 19 Uhr, wenn heute noch nicht gespielt wurde.
//  Wird bei jedem Wechsel in den Hintergrund und nach jeder Runde neu geplant.
//

import Foundation
import UserNotifications

enum StreakReminder {
    static let enabledKey = "streakReminder.enabled"
    private static let identifier = "streakReminder"
    private static let hour = 19

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Fragt die Berechtigung an. Gibt zurück, ob Erinnerungen erlaubt sind.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Plant die nächste Erinnerung (oder entfernt sie, wenn ausgeschaltet).
    static func reschedule(stats: GlobalStats) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard isEnabled else { return }

        let calendar = Calendar.current
        let playedToday = stats.lastPlayedDate.map { calendar.isDateInToday($0) } ?? false
        var day = Date()
        let pastReminderTime = calendar.component(.hour, from: day) >= hour
        if playedToday || pastReminderTime {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }

        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour

        let content = UNMutableNotificationContent()
        // Streak, die nach dem heutigen Spielen bestehen würde
        let streak = playedToday ? stats.currentStreak : max(stats.currentStreak, 0)
        if streak > 0 {
            content.title = "Deine \(streak)-Tage-Streak wartet 🔥"
            content.body = "Ein kurzes Quiz reicht, um sie heute zu halten."
        } else {
            content.title = "Zeit für ein Quiz 🧠"
            content.body = "Starte heute eine neue Streak – oder spiel die Tageschallenge."
        }
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
