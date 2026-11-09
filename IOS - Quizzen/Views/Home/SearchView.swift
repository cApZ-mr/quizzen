//
//  SearchView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 08.07.26.
//
//  Zwei Zustände:
//  - Entdecken (leeres Suchfeld): letzte Suchen, Personen-Vorschläge, alle Quizze
//  - Ergebnisse (beim Tippen): Personen und Quizze, Suche auch im Inhalt der Fragen
//

import Foundation
import SwiftUI

enum ResultFilter: CaseIterable {
    case all, people, quizzes

    var title: String {
        switch self {
        case .all: "Alle"
        case .people: "Personen"
        case .quizzes: "Quizze"
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var statsManager: StatsManager

    @State private var searchText = DebugLaunch.initialSearch
    @State private var filter: ResultFilter = .all


    @State private var accountResults: [AccountWithStats] = []
    @State private var isSearchingAccounts = false
    @State private var suggestedAccounts: [AccountWithStats] = []
    @State private var friendshipStatuses: [UUID: FriendshipStatusEntry] = [:]
    @State private var pendingRequestIds: Set<UUID> = []

    @AppStorage("recentSearches") private var recentSearchesData = ""

    private let allQuizzes = DataService.loadAllQuizzes()

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }
    private var isSearching: Bool { !query.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if isSearching {
                        resultsContent
                    } else {
                        discoverContent
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.2), value: isSearching)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isSearching ? "Ergebnisse" : "Entdecken")
            .navigationDestination(for: QuizDetail.self) { QuizDetailView(quiz: $0) }
            .navigationDestination(for: QuizCategory.self) { CategoryView(category: $0) }
            .navigationDestination(for: AccountWithStats.self) { PublicProfileView(account: $0.asAccount) }
        }
        .searchable(text: $searchText, prompt: "Quiz, Frage oder Person")
        .onSubmit(of: .search) { rememberSearch(query) }
        .task(id: query) { await performAccountSearch() }
        .task {
            async let suggestions: Void = loadSuggestions()
            async let statuses: Void = reloadFriendshipStatuses()
            _ = await (suggestions, statuses)
        }
    }

    // MARK: - Entdecken

    @ViewBuilder
    private var discoverContent: some View {
        if !recentSearches.isEmpty {
            recentSearchesSection
        }
        if !suggestedAccounts.isEmpty {
            suggestionsSection
        }
        categoriesSection
        allQuizzesSection
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Zuletzt gesucht") {
                Button("Löschen") { withAnimation { recentSearchesData = "" } }
                    .font(.subheadline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentSearches, id: \.self) { term in
                        Button {
                            searchText = term
                        } label: {
                            Label(term, systemImage: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Personen, die du kennen könntest")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestedAccounts) { account in
                        personCard(account)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func personCard(_ account: AccountWithStats) -> some View {
        let level = level(of: account)

        return VStack(spacing: 8) {
            NavigationLink(value: account) {
                VStack(spacing: 8) {
                    AvatarView(username: account.username, url: account.avatarUrl, size: 64)
                        .overlay(alignment: .bottomTrailing) {
                            levelBubble(level)
                                .offset(x: 4, y: 4)
                        }
                    HStack(spacing: 4) {
                        Text(account.username)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if let country = account.country, !country.isEmpty {
                            FlagImage(name: country.lowercased(), width: 16, height: 11)
                        }
                    }
                    Text(level.title)
                        .font(.caption)
                        .foregroundStyle(level.color)
                }
            }
            .buttonStyle(.plain)

            friendButton(for: account)
        }
        .frame(width: 132)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func friendButton(for account: AccountWithStats) -> some View {
        if let status = statusLabel(for: account.id) {
            Text(status.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.color)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(status.color.opacity(0.15), in: Capsule())
        } else {
            Button {
                Task { await sendRequest(to: account.id) }
            } label: {
                Group {
                    if pendingRequestIds.contains(account.id) {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Hinzufügen", systemImage: "person.badge.plus")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(Color.brand, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(pendingRequestIds.contains(account.id))
        }
    }

    // Themenbereiche als Kacheln
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Themenbereiche")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(QuizCatalog.categories) { category in
                    NavigationLink(value: category) {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(category.color.gradient, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(category.quizzes.count == 1 ? "1 Quiz" : "\(category.quizzes.count) Quizze")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var allQuizzesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Alle Quizze") {
                Text("\(allQuizzes.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Group {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(allQuizzes) { quiz in
                        NavigationLink(value: quiz) {
                            quizGridCard(quiz)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func quizGridCard(_ quiz: QuizDetail) -> some View {
        let progress = statsManager.getStats(for: quiz).percentFinished(totalQuestions: quiz.questionCount)

        return VStack(alignment: .leading, spacing: 8) {
            QuizCoverView(quiz: quiz)
                .frame(height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottom) {
                    if progress > 0 {
                        ProgressView(value: Double(progress), total: 100)
                            .tint(.white)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 8)
                    }
                }
            Text(quiz.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
            Text("\(quiz.questionCount) \(quiz.definition?.unit.plural ?? "Fragen") · \(quiz.definition?.presets.count ?? 1) Stufen")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ergebnisse

    @ViewBuilder
    private var resultsContent: some View {
        Picker("Ergebnisse", selection: $filter) {
            Text("Alle").tag(ResultFilter.all)
            Text("Personen (\(accountResults.count))").tag(ResultFilter.people)
            Text("Quizze (\(quizResults.count))").tag(ResultFilter.quizzes)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        let showPeople = filter != .quizzes
        let showQuizzes = filter != .people
        let nothingFound = !isSearchingAccounts && accountResults.isEmpty && quizResults.isEmpty

        if nothingFound {
            ContentUnavailableView.search(text: query)
                .padding(.top, 40)
        } else {
            if showQuizzes && !quizResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Quizze")
                    resultCard {
                        ForEach(Array(quizResults.prefix(filter == .quizzes ? .max : 5).enumerated()), id: \.element.id) { index, quiz in
                            if index > 0 { Divider().padding(.leading, 76) }
                            NavigationLink(value: quiz) {
                                quizResultRow(quiz)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { rememberSearch(query) })
                        }
                    }
                    if filter == .all && quizResults.count > 5 {
                        showAllButton("Alle \(quizResults.count) Quizze") { filter = .quizzes }
                    }
                }
            }

            if showPeople {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Personen") {
                        if isSearchingAccounts { ProgressView().controlSize(.small) }
                    }
                    if accountResults.isEmpty && !isSearchingAccounts {
                        Text("Keine Person heißt so.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    } else {
                        resultCard {
                            ForEach(Array(accountResults.prefix(filter == .people ? .max : 5).enumerated()), id: \.element.id) { index, account in
                                if index > 0 { Divider().padding(.leading, 72) }
                                NavigationLink(value: account) {
                                    personResultRow(account)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded { rememberSearch(query) })
                            }
                        }
                        if filter == .all && accountResults.count > 5 {
                            showAllButton("Alle \(accountResults.count) Personen") { filter = .people }
                        }
                    }
                }
            }
        }
    }

    private func quizResultRow(_ quiz: QuizDetail) -> some View {
        let progress = statsManager.getStats(for: quiz).percentFinished(totalQuestions: quiz.questionCount)
        let matches = questionMatches(in: quiz)

        return HStack(spacing: 14) {
            QuizCoverView(quiz: quiz)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(highlighted(quiz.title))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if matches > 0 {
                        Text(matches == 1 ? "1 passende Frage" : "\(matches) passende Fragen")
                            .foregroundStyle(Color.brandLight)
                    } else {
                        Text(QuizCatalog.category(for: quiz.id)?.name ?? "\(quiz.questionCount) Fragen")
                    }
                    if progress > 0 {
                        Text("·")
                        Text("\(progress) % gesehen")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func personResultRow(_ account: AccountWithStats) -> some View {
        let level = level(of: account)

        return HStack(spacing: 12) {
            AvatarView(username: account.username, url: account.avatarUrl, size: 46)
                .overlay(alignment: .bottomTrailing) { levelBubble(level).offset(x: 3, y: 3) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(highlighted(account.username))
                        .font(.subheadline.weight(.semibold))
                    if let country = account.country, !country.isEmpty {
                        FlagImage(name: country.lowercased(), width: 18, height: 12)
                    }
                }
                Text("Level \(level.level) · \(level.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let status = statusLabel(for: account.id) {
                Text(status.text)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(status.color)
                    .background(status.color.opacity(0.15), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Bausteine

    private func sectionHeader<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            trailing()
        }
        .padding(.horizontal)
    }

    private func resultCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal)
    }

    private func showAllButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            HStack {
                Text(title)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal)
    }

    private func levelBubble(_ level: PlayerLevel) -> some View {
        Text("\(level.level)")
            .font(.system(.caption2, design: .rounded, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(level.color, in: Circle())
            .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2))
    }

    /// Markiert den Suchbegriff im Text fett/farbig
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        if let range = attributed.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].foregroundColor = .brandLight
        }
        return attributed
    }

    // MARK: - Daten & Logik

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var searchTerms: [String] {
        query.split(separator: " ").map { Self.normalize(String($0)) }
    }

    /// Wie viele Fragen (inkl. Antworten) eines Quiz den Suchbegriff enthalten
    private func questionMatches(in quiz: QuizDetail) -> Int {
        let terms = searchTerms
        guard !terms.isEmpty else { return 0 }
        return quiz.questions.filter { question in
            let text = Self.normalize(([question.question] + question.options).joined(separator: " "))
            return terms.allSatisfy { text.contains($0) }
        }.count
    }

    /// Quiz-Treffer: Titel/Beschreibung oder passende Fragen. Titel-Treffer zuerst.
    private var quizResults: [QuizDetail] {
        let terms = searchTerms
        guard !terms.isEmpty else { return [] }
        func titleMatch(_ quiz: QuizDetail) -> Bool {
            let text = Self.normalize([quiz.title, quiz.description, QuizCatalog.category(for: quiz.id)?.name ?? ""]
                .joined(separator: " "))
            return terms.allSatisfy { text.contains($0) }
        }
        return allQuizzes
            .filter { titleMatch($0) || questionMatches(in: $0) > 0 }
            .sorted { titleMatch($0) && !titleMatch($1) }
    }

    private func level(of account: AccountWithStats) -> PlayerLevel {
        guard let stats = account.stats else { return PlayerLevel(correctAnswers: 0, quizzesPlayed: 0) }
        return GlobalStats(from: stats).level
    }

    private func performAccountSearch() async {
        filter = .all
        guard !query.isEmpty else {
            accountResults = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))   // Debounce
        guard !Task.isCancelled else { return }

        isSearchingAccounts = true
        defer { isSearchingAccounts = false }
        let results = (try? await supabase.searchAccounts(query: query)) ?? []
        guard !Task.isCancelled else { return }
        accountResults = results
    }

    private func loadSuggestions() async {
        guard suggestedAccounts.isEmpty else { return }
        do {
            suggestedAccounts = try await supabase.fetchSuggestedAccounts(count: 8)
        } catch {
            log.error("Fehler beim Laden der Vorschläge: \(error.localizedDescription)")
        }
    }

    private func reloadFriendshipStatuses() async {
        friendshipStatuses = (try? await supabase.fetchAllFriendshipStatuses()) ?? friendshipStatuses
    }

    private func sendRequest(to id: UUID) async {
        pendingRequestIds.insert(id)
        defer { pendingRequestIds.remove(id) }
        do {
            try await supabase.sendFriendRequest(to: id)
            await reloadFriendshipStatuses()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            log.error("Freundschaftsanfrage fehlgeschlagen: \(error.localizedDescription)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func statusLabel(for accountId: UUID) -> (text: String, color: Color)? {
        guard let entry = friendshipStatuses[accountId] else { return nil }
        switch entry.status {
        case .accepted: return ("Befreundet", .green)
        case .pending:  return entry.iAmRequester ? ("Angefragt", .orange) : ("Fragt dich an", .blue)
        case .declined: return nil
        }
    }

    // MARK: Letzte Suchen (nur lokal auf dem Gerät)

    private var recentSearches: [String] {
        recentSearchesData.split(separator: "\n").map(String.init)
    }

    private func rememberSearch(_ term: String) {
        let term = term.trimmingCharacters(in: .whitespaces)
        guard term.count >= 2 else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        list.insert(term, at: 0)
        recentSearchesData = list.prefix(8).joined(separator: "\n")
    }
}
