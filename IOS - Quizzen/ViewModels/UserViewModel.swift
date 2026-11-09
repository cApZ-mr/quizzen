//
//  UserViewModel.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 09.07.26.
//

import Foundation
import SwiftUI
import PhotosUI
import Combine
import Supabase

class UserViewModel: ObservableObject {
    @AppStorage("username") var username: String = ""
    @Published var email: String = ""
    @AppStorage("selectedOriginCode") var selectedOriginCode: String = ""
    @AppStorage("selectedLanguageCode") var selectedLanguageCode: String = ""
    /// Registrierungsdatum (accounts.created_at) für „Dabei seit“ / Mitglied-Badge
    @AppStorage("accountCreatedAt") var accountCreatedAtTimestamp: Double = 0

    var accountCreatedAt: Date? {
        accountCreatedAtTimestamp > 0 ? Date(timeIntervalSince1970: accountCreatedAtTimestamp) : nil
    }

    /// Profilbild liegt als Datei im Caches-Ordner, nicht in UserDefaults.
    @Published var profileImageData: Data? {
        didSet { ProfileImageCache.save(profileImageData) }
    }

    @Published var password: String = ""

    init() {
        ProfileImageCache.migrateFromUserDefaults()
        profileImageData = ProfileImageCache.load()
    }

    var profileImage: Image {
        if let data = profileImageData, let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "person.crop.circle.fill")
    }

    var countries: [Country] { Self.allCountries }

    /// Entfernt alle nutzerbezogenen lokalen Daten (z. B. beim Logout),
    /// damit der nächste Account nichts vom vorherigen übernimmt.
    func clearLocalData() {
        username = ""
        accountCreatedAtTimestamp = 0
        email = ""
        password = ""
        selectedOriginCode = ""
        profileImageData = nil
        UserDefaults.standard.removeObject(forKey: "recentSearches")
    }
}

nonisolated struct AccountRow: Decodable {
    let username: String
    let avatar_url: String?
    let country: String
    let created_at: Date?
}

extension UserViewModel {
    func loadProfile() async {
        do {
            let user = try await supabase.auth.user()
            let userId = user.id

            let row: AccountRow = try await supabase
                .from("accounts")
                .select("username, avatar_url, country, created_at")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            self.username = row.username
            self.selectedOriginCode = row.country
            if let created = row.created_at { self.accountCreatedAtTimestamp = created.timeIntervalSince1970 }
            self.email = user.email ?? ""

            if let urlString = row.avatar_url, let url = URL(string: urlString) {
                let (data, _) = try await URLSession.shared.data(from: url)
                self.profileImageData = data
            } else {
                self.profileImageData = nil
            }
        } catch {
            log.error("Profil konnte nicht geladen werden: \(error.localizedDescription)")
        }
    }
}

// MARK: - Profilbild-Cache

enum ProfileImageCache {
    private static let legacyDefaultsKey = "profileImageData"

    private static var fileURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_image.jpg")
    }

    static func load() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    static func save(_ data: Data?) {
        if let data {
            try? data.write(to: fileURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Einmalige Migration: altes Bild aus UserDefaults in die Datei verschieben.
    static func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.data(forKey: legacyDefaultsKey) else { return }
        save(legacy)
        defaults.removeObject(forKey: legacyDefaultsKey)
    }

    /// Verkleinert ein Bild auf max. `maxDimension` px und gibt echtes JPEG zurück
    /// (PhotosPicker liefert sonst evtl. HEIC/PNG in voller Auflösung).
    static func jpegForUpload(_ data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
