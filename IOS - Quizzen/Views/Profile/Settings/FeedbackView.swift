//
//  FeedbackView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 29.06.26.
//

import Foundation
import SwiftUI
import PhotosUI
import Supabase
import Storage

// MARK: - Datenmodell (Datenbank verbindung)
nonisolated struct FeedbackInsert: Encodable {
    let user_id: String
    let message: String
    let image_urls: [String]
}

struct FeedbackView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImagesData: [Data] = []
    @State private var isLoading = false

    @State private var feedbackText: String = ""
    @State private var isSending = false
    @State private var didSend = false

    private let maxImages = 5
    private let maxCharacters = 500

    private var canSend: Bool {
        !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                header

                descriptionSection

                imagesSection

                Spacer(minLength: 8)

                sendButton
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hilf uns, Quizzen zu verbessern")
                .font(.title3.bold())
            Text("Beschreibe dein Anliegen oder melde einen Fehler. Screenshots helfen uns, das Problem schneller zu verstehen.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Beschreibung
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Beschreibung")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))

                if feedbackText.isEmpty {
                    Text("Was möchtest du uns mitteilen?")
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $feedbackText)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .onChange(of: feedbackText) { _, newValue in
                        if newValue.count > maxCharacters {
                            feedbackText = String(newValue.prefix(maxCharacters))
                        }
                    }
            }
            .frame(height: 160)

            Text("\(feedbackText.count)/\(maxCharacters)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Bilder
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bilder")
                    .font(.headline)
                Spacer()
                Text("\(selectedImagesData.count)/\(maxImages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(selectedImagesData.enumerated()), id: \.offset) { index, data in
                        imageThumbnail(data: data, index: index)
                    }

                    if selectedImagesData.count < maxImages {
                        addImageButton
                    }
                }
            }
            .frame(height: 100)

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                    Text("Bilder werden geladen…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func imageThumbnail(data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                removeImage(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(.white, Color.black.opacity(0.6))
            }
            .padding(4)
        }
    }

    private func removeImage(at index: Int) {
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            selectedImagesData.remove(at: index)
        }
    }

    private var addImageButton: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: maxImages - selectedImagesData.count,
            matching: .images
        ) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(.title3, weight: .semibold))
                Text("Hinzufügen")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .onChange(of: selectedItems) { _, newItems in
            Task { await loadImages(from: newItems) }
        }
    }

    // MARK: - Senden
    private var sendButton: some View {
        HStack {
            Spacer()
            Button {
                sendFeedback()
            } label: {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else if didSend {
                        Image(systemName: "checkmark")
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(didSend ? String(localized: "Gesendet") : String(localized: "Senden"))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(canSend ? Color.blue : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSend || isSending || didSend)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
    }

    // MARK: - Logik
    private func loadImages(from items: [PhotosPickerItem]) async {
        isLoading = true
        defer { isLoading = false }

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    if selectedImagesData.count < maxImages {
                        selectedImagesData.append(data)
                    }
                }
            }
        }

        await MainActor.run {
            selectedItems = []
        }
    }

    
    // MARK: Feedback Absenden
    private func sendFeedback() {
        isSending = true

        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id

                var imageUrls: [String] = []

                for (index, imageData) in selectedImagesData.enumerated() {
                    let fileName = "\(userId.uuidString)/\(UUID().uuidString)-\(index).jpg"

                    try await supabase.storage
                        .from("feedback-images")
                        .upload(fileName, data: imageData, options: FileOptions(contentType: "image/jpeg"))

                    let publicUrl = try supabase.storage
                        .from("feedback-images")
                        .getPublicURL(path: fileName)
                        .absoluteString

                    imageUrls.append(publicUrl)
                }

                let feedback = FeedbackInsert(
                    user_id: userId.uuidString,
                    message: feedbackText,
                    image_urls: imageUrls
                )

                try await supabase
                    .from("feedback")
                    .insert(feedback)
                    .execute()

                // 4. UI-Feedback bei Erfolg
                await MainActor.run {
                    isSending = false
                    withAnimation {
                        didSend = true
                    }
                }

            } catch {
                log.error("Fehler beim Senden des Feedbacks: \(error.localizedDescription)")
                await MainActor.run {
                    isSending = false
                    // Optional: Fehlerzustand anzeigen, ähnlich wie signUpFailed im Signup
                }
            }
        }
    }
    
    
}


#Preview {
    NavigationStack {
        FeedbackView()
    }
}
