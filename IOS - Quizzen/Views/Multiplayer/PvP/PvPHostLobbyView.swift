//
//  PvPHostLobbyView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 11.07.26.
//
//  Warteraum für beide Seiten:
//  - Host: Code teilen, auf Gast warten, dann Quiz wählen und starten
//  - Gast: sieht, dass er drin ist und der Host gerade ein Quiz wählt
//

import SwiftUI

struct PvPWaitingRoom: View {
    @ObservedObject var session: PvPSession

    @State private var selectedQuiz: QuizDetail?
    @State private var duelSetup = DuelSetup()
    @State private var pulse = false

    private var selectedDefinition: QuizDefinition? {
        selectedQuiz.flatMap { QuizCatalog.definition(for: $0.id) }
    }

    /// Mit diesen Einstellungen gibt es genug Fragen
    private var canStart: Bool {
        guard let definition = selectedDefinition else { return false }
        return definition.availableCount(for: duelSetup.resolved(for: definition).config) > 0
    }


    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PvPPlayersHeader(session: session)
                    .padding(.top, 12)

                if session.phase == .waitingForOpponent {
                    if let friend = session.invitedFriend {
                        Label("Einladung an \(friend.username) gesendet – sie erscheint dort im Duell-Tab. Alternativ den Code teilen:",
                              systemImage: "paperplane.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    inviteCard
                    waitingIndicator("Warte, bis dein Freund beitritt…")
                } else if session.isHost {
                    quizPicker
                    if let definition = selectedDefinition {
                        PvPDuelSettingsPanel(definition: definition, setup: $duelSetup)
                            .id(definition.id)
                    }
                } else {
                    waitingIndicator("\(session.opponentName) wählt gerade ein Quiz aus…")
                }

                if let error = session.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            if session.isHost && session.phase == .lobby {
                startButton
            }
        }
    }

    // MARK: Einladung

    private var inviteCard: some View {
        let code = session.match?.invite_code ?? "------"

        return VStack(spacing: 16) {
            Text("Dein Einladungscode")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 6) {
                ForEach(Array(code.enumerated()), id: \.offset) { _, digit in
                    Text(String(digit))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 54)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Code \(code.map(String.init).joined(separator: " "))")

            HStack(spacing: 10) {
                ShareLink(item: "Lass uns ein Quizzen-Duell spielen! ⚔️ Öffne die App, tippe auf „Duell“ → „Beitreten“ und gib diesen Code ein: \(code)") {
                    Label("Code teilen", systemImage: "square.and.arrow.up")
                }
                Button {
                    UIPasteboard.general.string = code
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Kopieren", systemImage: "doc.on.doc")
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.brand, Color.brandLight], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .shadow(color: Color.brand.opacity(0.35), radius: 16, y: 8)
    }

    private func waitingIndicator(_ text: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.brandLight.opacity(0.4), lineWidth: 3)
                    .frame(width: 22, height: 22)
                    .scaleEffect(pulse ? 2.2 : 1)
                    .opacity(pulse ? 0 : 1)
                Circle().fill(Color.brandLight).frame(width: 12, height: 12)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true }
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: Quiz-Auswahl (Host)

    private var quizPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wähle ein Quiz").font(.title3.bold())
                Text("Danach wählst du die Schwierigkeit oder eigene Einstellungen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(QuizCatalog.categories) { category in
                Label(category.name, systemImage: category.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(category.color)
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(category.quizzes) { definition in
                        quizCard(definition.baseQuiz)
                    }
                }
            }
        }
    }

    private func quizCard(_ quiz: QuizDetail) -> some View {
        let isSelected = selectedQuiz?.id == quiz.id
        return Button {
            withAnimation(.snappy) { selectedQuiz = quiz }
            if let definition = QuizCatalog.definition(for: quiz.id) { duelSetup.adapt(to: definition) }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                QuizCoverView(quiz: quiz)
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, Color.brand)
                                .padding(6)
                        }
                    }
                Text(quiz.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(quiz.questionCount) \(quiz.definition?.unit.plural ?? "Fragen")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.brandLight : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        Button {
            guard let definition = selectedDefinition else { return }
            let resolved = duelSetup.resolved(for: definition)
            Task { await session.start(definition: definition, config: resolved.config,
                                       duration: resolved.duration, label: resolved.label) }
        } label: {
            Group {
                if session.isBusy {
                    ProgressView().tint(.white)
                } else if let quiz = selectedQuiz, let definition = selectedDefinition {
                    Label(canStart ? "\(quiz.title) · \(duelSetup.resolved(for: definition).label) starten" : "Keine passenden Fragen",
                          systemImage: "play.fill")
                } else {
                    Text("Wähle zuerst ein Quiz")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(!canStart ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(Color.brand),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(!canStart || session.isBusy)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
