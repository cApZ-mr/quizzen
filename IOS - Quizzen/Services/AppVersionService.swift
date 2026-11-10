//
//  AppVersionService.swift
//  IOS - Quizzen
//

import Foundation
import UIKit

/// Infos zur neuesten Version im App Store.
struct StoreRelease: Equatable {
    let version: String
    let releaseNotes: String?
}

// MARK: - Version checken
enum AppVersionService {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6771577989")!

    /// Liefert die Store-Version, wenn sie NEUER ist als die installierte
    /// (z. B. 2.0.3 > 2.0.2) und sich auf diesem Gerät installieren lässt.
    /// Dev-/TestFlight-/Review-Builds mit höherer Nummer werden nie gesperrt.
    static func requiredUpdate() async -> StoreRelease? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-forceUpdate") {
            return StoreRelease(version: "9.9.9", releaseNotes: "Testanzeige für das Pflicht-Update.")
        }
        #endif

        guard let bundleId = Bundle.main.bundleIdentifier,
              let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return nil }

        // Ohne Länderangabe fragt Apple den US-Store ab – die App ist aber im
        // deutschen Store. Zeitstempel umgeht Zwischenspeicher.
        let country = Locale.current.region?.identifier.lowercased() ?? "de"
        let stamp = Int(Date().timeIntervalSince1970)

        for store in Array(Set([country, "de"])) {
            guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=\(store)&t=\(stamp)"),
                  let result = await lookup(url) else { continue }
            guard isVersion(result.version, newerThan: currentVersion) else { return nil }
            // Neue Version braucht ein neueres iOS als das Gerät hat → nicht aussperren
            if let minimum = result.minimumOsVersion,
               isVersion(minimum, newerThan: UIDevice.current.systemVersion) {
                return nil
            }
            return StoreRelease(version: result.version, releaseNotes: result.releaseNotes)
        }
        return nil
    }

    private struct LookupResponse: Decodable {
        struct Result: Decodable {
            let version: String
            let releaseNotes: String?
            let minimumOsVersion: String?
        }
        let results: [Result]
    }

    private static func lookup(_ url: URL) async -> LookupResponse.Result? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(LookupResponse.self, from: data).results.first
        } catch {
            log.info("Versions-Check fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    nonisolated static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedDescending
    }
}
