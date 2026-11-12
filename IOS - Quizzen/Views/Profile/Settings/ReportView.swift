//
//  ReportView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 29.06.26.
//

import Foundation
import SwiftUI
import PhotosUI
import Supabase
import Storage

// MARK: - Datenmodell
nonisolated struct ReportInsert: Encodable {
    let user_id: String
    let reason: String
    let message: String
    let image_urls: [String]
}

struct ReportView: View {
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImagesData: [Data] = []
    @State private var isLoading = false
    
    @State private var reportText: String = ""
    @State private var selectedReason: String = String(localized: "Inhalt fehlerhaft")
    @State private var isSending = false
    @State private var didSend = false
    
    private let reasons = [String(localized: "Inhalt fehlerhaft"), String(localized: "Unangemessen"), String(localized: "Technisches Problem"), String(localized: "Sonstiges")]
    private let maxImages = 5
    private let maxCharacters = 500
    
    private var canSend: Bool {
        !reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                
                reasonSection
                
                descriptionSection
                
                imagesSection
                
                Spacer(minLength: 8)
                
                sendButton
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Inhalt melden")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inhalt melden")
                .font(.title3.bold())
            Text("Vielen Dank, dass du uns dabei hilfst, Quizzen sicher und korrekt zu halten.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Meldegrund
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grund")
                .font(.headline)
            
            Picker("Grund", selection: $selectedReason) {
                ForEach(reasons, id: \.self) { reason in
                    Text(reason).tag(reason)
                }
            }
            .pickerStyle(.segmented)
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
                
                if reportText.isEmpty {
                    Text("Was möchtest du uns mitteilen?")
                        .foregroundColor(Color(.placeholderText))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                
                TextEditor(text: $reportText)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .onChange(of: reportText) { _, newValue in
                        if newValue.count > maxCharacters {
                            reportText = String(newValue.prefix(maxCharacters))
                        }
                    }
            }
            .frame(height: 160)
            
            Text("\(reportText.count)/\(maxCharacters)")
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
            Button { removeImage(at: index) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(.title3))
                    .foregroundStyle(.white, Color.black.opacity(0.6))
            }
            .padding(4)
        }
    }
    
    private func removeImage(at index: Int) {
        _ = withAnimation(.easeInOut(duration: 0.2)) { selectedImagesData.remove(at: index) }
    }
    
    private var addImageButton: some View {
        PhotosPicker(selection: $selectedItems, maxSelectionCount: maxImages - selectedImagesData.count, matching: .images) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(.title3, weight: .semibold))
                Text("Hinzufügen")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .frame(width: 100, height: 100)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
        }
        .onChange(of: selectedItems) { _, newItems in Task { await loadImages(from: newItems) } }
    }
    
    // MARK: - Logik
    private func loadImages(from items: [PhotosPickerItem]) async {
        isLoading = true
        defer { isLoading = false }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { if selectedImagesData.count < maxImages { selectedImagesData.append(data) } }
            }
        }
        await MainActor.run { selectedItems = [] }
    }
    
    private var sendButton: some View {
        HStack {
            Spacer()
            Button { sendReport() } label: {
                HStack(spacing: 8) {
                    if isSending { ProgressView().tint(.white) }
                    else if didSend { Image(systemName: "checkmark") }
                    else { Image(systemName: "paperplane.fill") }
                    Text(didSend ? "Gemeldet" : "Bericht senden")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(canSend ? Color.blue : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled(!canSend || isSending || didSend)
        }
    }
    
    private func sendReport() {
        isSending = true
        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                var imageUrls: [String] = []
                
                for (index, imageData) in selectedImagesData.enumerated() {
                    let fileName = "\(userId.uuidString)/\(UUID().uuidString)-\(index).jpg"
                    try await supabase.storage.from("feedback-images").upload(fileName, data: imageData, options: FileOptions(contentType: "image/jpeg"))
                    let publicUrl = try supabase.storage.from("feedback-images").getPublicURL(path: fileName).absoluteString
                    imageUrls.append(publicUrl)
                }
                
                let report = ReportInsert(user_id: userId.uuidString, reason: selectedReason, message: reportText, image_urls: imageUrls)
                try await supabase.from("reports").insert(report).execute()
                
                await MainActor.run { isSending = false; withAnimation { didSend = true } }
            } catch {
                log.error("Fehler beim Senden: \(error.localizedDescription)")
                await MainActor.run { isSending = false }
            }
        }
    }
}
