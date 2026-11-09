//
//  FlagImage.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.06.26.
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - Globaler Cache für downgesampelte Flaggen
final class FlagImageCache {
    static let shared = FlagImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 250 // grobe Obergrenze, NSCache räumt bei Speicherdruck zusätzlich automatisch auf
    }

    func image(for name: String, maxPixelSize: CGFloat, scale: CGFloat) -> UIImage? {
        let key = "\(name)_\(Int(maxPixelSize))" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let downsampled = Self.downsample(imageName: name, maxPixelSize: maxPixelSize, scale: scale) else {
            return nil
        }

        cache.setObject(downsampled, forKey: key)
        return downsampled
    }

    private static func downsample(imageName: String, maxPixelSize: CGFloat, scale: CGFloat) -> UIImage? {
        // Holt die Original-Bilddaten aus dem Asset-Catalog
        guard let asset = UIImage(named: imageName) else { return nil }
        guard let data = asset.pngData() ?? asset.jpegData(compressionQuality: 1) else { return nil }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

// MARK: - SwiftUI View, die die downgesampelte Flagge anzeigt
struct FlagImage: View {
    let name: String
    let width: CGFloat
    let height: CGFloat

    @State private var uiImage: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.08) // Platzhalter während des Ladens
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: name) {
            let maxPixelSize = max(width, height) * displayScale
            uiImage = FlagImageCache.shared.image(for: name, maxPixelSize: maxPixelSize, scale: displayScale)
        }
    }
}
