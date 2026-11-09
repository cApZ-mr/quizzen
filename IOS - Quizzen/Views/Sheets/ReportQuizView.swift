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
    @State private var showMail = false
    @State private var showNoMailAlert = false
    
    
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
                    Button("Absenden") {
                        if MFMailComposeViewController.canSendMail() {
                            showMail = true
                        } else {
                            showNoMailAlert = true
                        }
                    }
                }
            }
            .navigationTitle("Frage Melden")
            .sheet(isPresented: $showMail) {
                MailView(
                    isShowing: $showMail,
                    subject: "Report: \(selectedReason)",
                    bodyText: "Quiz: \(quiz.title) \nAnliegen: \(selectedReason) \nFrage: \(viewModel.currentQuestion.question) \n\nBeschreibung:\n\(beschreibung)",
                    recipient: "support@quizzen-app.com",
                )
            }
            .onAppear {
                // Setze Standardwert beim Laden
                if selectedQuizId.isEmpty {
                    selectedQuizId = allQuizzes.first?.id ?? ""
                }
            }
        }
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
