//
//  ReportView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 10.06.26.
//


import Foundation
import MessageUI
import SwiftUI

// MARK: - ReportView
struct ReportQuizView: View {
    let allQuizzes = DataService.loadAllQuizzes()
    let quiz: QuizDetail
    
    @ObservedObject var viewModel: QuizViewModel
    
    @State private var selectedQuizId = ""
    @State private var selectedReason = "Frage Fehlerhaft"
    @State private var beschreibung = ""
    @State private var mailDraft: MailDraft?
    @State private var showNoMailAlert = false
    @Environment(\.openURL) private var openURL

    private let recipient = AppLinks.supportEmail
    
    
    let anliegenReason = ["Frage Fehlerhaft", "Frage unpassend", "Antwortmöglichkeiten Fehlerhaft", "Sonstiges"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    Text("Quiz: \(quiz.title)")
                    Text("Frage:  \(viewModel.currentQuestion.prompt(quizId: quiz.id))")
                }
                
                Section(header: Text("Meldungsgrund")) {
                    Picker("Grund", selection: $selectedReason) {
                        ForEach(anliegenReason, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
                Section(header: Text("Beschreibung")) {
                    TextEditor(text: $beschreibung)
                        .frame(minHeight: 100)
                }
                
                
                Section {
                    Button("Absenden") { send() }
                }
            }
            .navigationTitle("Frage Melden")
            // Inhalt wird beim Tippen auf „Absenden“ festgehalten und übergeben
            .sheet(item: $mailDraft) { draft in
                MailView(
                    isShowing: Binding(get: { mailDraft != nil }, set: { if !$0 { mailDraft = nil } }),
                    subject: draft.subject,
                    bodyText: draft.body,
                    recipient: recipient
                )
            }
            .alert("Keine Mail-App eingerichtet", isPresented: $showNoMailAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Bitte schreib uns direkt an \(recipient).")
            }
            .onAppear {
                // Setze Standardwert beim Laden
                if selectedQuizId.isEmpty {
                    selectedQuizId = allQuizzes.first?.id ?? ""
                }
            }
        }
    }

    private func send() {
        let question = viewModel.currentQuestion
        let text = beschreibung.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = MailDraft(
            subject: "Report: \(selectedReason) – \(quiz.title)",
            body: """
            Quiz: \(quiz.title)
            Anliegen: \(selectedReason)
            Frage: \(question.prompt(quizId: quiz.id))
            Richtige Antwort: \(question.options.indices.contains(question.correctAnswerIndex) ? question.options[question.correctAnswerIndex] : "–")
            Bild: \(question.imageName ?? "–")

            Beschreibung:
            \(text.isEmpty ? "–" : text)
            """
        )
        if MFMailComposeViewController.canSendMail() {
            mailDraft = draft
        } else if let url = draft.mailtoURL(to: recipient) {
            openURL(url) { accepted in
                if !accepted { showNoMailAlert = true }
            }
        } else {
            showNoMailAlert = true
        }
    }
}

/// Fertig zusammengestellte Mail (wird beim Absenden erzeugt)
struct MailDraft: Identifiable {
    let id = UUID()
    let subject: String
    let body: String

    func mailtoURL(to recipient: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [URLQueryItem(name: "subject", value: subject),
                                 URLQueryItem(name: "body", value: body)]
        return components.url
    }
}

// MARK: - MailView
struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    var subject: String
    var bodyText: String
    var recipient: String
    var attachmentData: Data?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setMessageBody(bodyText, isHTML: false)
        vc.setToRecipients([recipient])
        
        if let data = attachmentData {
            vc.addAttachmentData(data, mimeType: "image/jpeg", fileName: "feedback_image.jpg")
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        init(_ parent: MailView) { self.parent = parent }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isShowing = false
        }
    }
}
