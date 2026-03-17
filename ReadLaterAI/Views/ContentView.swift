import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ContentView — Liquid Glass Design

struct ContentView: View {

    enum ViewMode: Equatable {
        case articles
        case safariImport(URL)
        case preferences
        case onboarding
        case help

        static func == (lhs: ViewMode, rhs: ViewMode) -> Bool {
            switch (lhs, rhs) {
            case (.articles, .articles), (.preferences, .preferences),
                 (.onboarding, .onboarding), (.help, .help): true
            case (.safariImport(let a), .safariImport(let b)): a == b
            default: false
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.dateAdded, order: .reverse) private var articles: [Article]

    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var extractor = ArticleExtractor()
    @State private var clipboardMonitor = ClipboardMonitor()
    @State private var viewMode: ViewMode = .articles
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    // Recherche & filtres
    @State private var searchText: String = ""
    @State private var activeFilter: ArticleFilter = .all
    @State private var isSearching: Bool = false

    // Enum des filtres disponibles.
    // C'est comme un système de routes/tabs pour filtrer la liste.
    enum ArticleFilter: String, CaseIterable {
        case all
        case unread
        case summarized
        case failed

        var label: String {
            switch self {
            case .all: String(localized: "All")
            case .unread: String(localized: "Unread")
            case .summarized: String(localized: "Summarized")
            case .failed: String(localized: "Failed")
            }
        }

        var icon: String {
            switch self {
            case .all: "tray.full"
            case .unread: "circle"
            case .summarized: "checkmark.circle"
            case .failed: "exclamationmark.triangle"
            }
        }
    }

    /// Articles filtrés selon la recherche et le filtre actif.
    /// C'est une propriété calculée (computed property) — l'équivalent d'un `computed()`
    /// en Vue.js. Elle se recalcule automatiquement quand ses dépendances changent.
    private var filteredArticles: [Article] {
        var result = articles

        // Appliquer le filtre
        switch activeFilter {
        case .all:
            break
        case .unread:
            result = result.filter { !$0.isRead }
        case .summarized:
            result = result.filter { $0.summary != nil }
        case .failed:
            result = result.filter { $0.extractedText == nil }
        }

        // Appliquer la recherche
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.url.lowercased().contains(query) ||
                ($0.summary?.tags.contains(where: { $0.lowercased().contains(query) }) ?? false) ||
                ($0.summary?.tldr.lowercased().contains(query) ?? false)
            }
        }

        return result
    }

    var onQuit: (() -> Void)?

    var body: some View {
        ZStack {
            switch viewMode {
            case .articles:
                articlesView.transition(.opacity)
            case .safariImport(let url):
                SafariImportView(
                    bookmarksFileURL: url,
                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = .articles } }
                ).transition(.move(edge: .trailing).combined(with: .opacity))
            case .preferences:
                PreferencesView(
                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = .articles } }
                ).transition(.move(edge: .trailing).combined(with: .opacity))
            case .onboarding:
                OnboardingView(
                    onDismiss: {
                        hasSeenOnboarding = true
                        withAnimation(.easeInOut(duration: 0.3)) { viewMode = .articles }
                    }
                ).transition(.opacity)
            case .help:
                HelpView(
                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = .articles } }
                ).transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: 400, height: 540)
        .background(.ultraThinMaterial)
        .task { clipboardMonitor.start() }
        .onAppear { if !hasSeenOnboarding { viewMode = .onboarding } }
    }

    // MARK: - Articles View

    private var articlesView: some View {
        VStack(spacing: 0) {
            headerSection

            if let detected = clipboardMonitor.detectedURL {
                clipboardBanner(url: detected)
            }

            // Barre de filtres (visible seulement s'il y a des articles)
            if !articles.isEmpty {
                filterBar
            }

            articleListSection
            footerSection
        }
    }

    // MARK: - Header (URL input + search toggle)

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if isSearching {
                    // Mode recherche
                    Image(systemName: "magnifyingglass")
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)

                    TextField("Search articles…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearching = false
                            searchText = ""
                        }
                    } label: {
                        Text("Cancel")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else {
                    // Mode ajout URL
                    Image(systemName: "link.badge.plus")
                        .font(.callout)
                        .foregroundStyle(.tertiary)

                    TextField("Paste or enter a URL…", text: $urlInput)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .onSubmit { addArticle() }

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        // Bouton recherche (visible seulement s'il y a des articles)
                        if !articles.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSearching = true
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.callout)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                        }

                        Button { addArticle() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(urlInput.isEmpty ? Color.gray.opacity(0.2) : Color.accentColor)
                        .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSearching ? Color.accentColor.opacity(0.04) : Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSearching ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )

            if let errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(errorMessage)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Clipboard Banner

    private func clipboardBanner(url: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.callout)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 1) {
                Text("URL detected")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                Text(url)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                urlInput = url
                clipboardMonitor.clearDetectedURL()
                addArticle()
            } label: {
                Text("Add")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(GlassButtonStyle(color: .blue))

            Button {
                withAnimation { clipboardMonitor.clearDetectedURL() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.05))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ArticleFilter.allCases, id: \.self) { filter in
                    let count = countForFilter(filter)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeFilter = activeFilter == filter ? .all : filter
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(.caption2)
                            Text(filter.label)
                                .font(.caption)
                            if filter != .all && count > 0 {
                                Text("\(count)")
                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                    .foregroundStyle(activeFilter == filter ? .primary : .tertiary)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(activeFilter == filter
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.primary.opacity(0.04))
                                .overlay(
                                    Capsule()
                                        .stroke(activeFilter == filter
                                                ? Color.accentColor.opacity(0.3)
                                                : Color.clear, lineWidth: 0.5)
                                )
                        )
                        .foregroundStyle(activeFilter == filter ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    /// Compte les articles pour chaque filtre (pour les badges).
    private func countForFilter(_ filter: ArticleFilter) -> Int {
        switch filter {
        case .all: articles.count
        case .unread: articles.filter { !$0.isRead }.count
        case .summarized: articles.filter { $0.summary != nil }.count
        case .failed: articles.filter { $0.extractedText == nil }.count
        }
    }

    // MARK: - Article List

    private var articleListSection: some View {
        Group {
            if articles.isEmpty {
                emptyState
            } else if filteredArticles.isEmpty {
                // Recherche ou filtre sans résultat
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("No results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !searchText.isEmpty {
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Button("Show all") {
                            withAnimation { activeFilter = .all }
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredArticles) { article in
                            ArticleRow(article: article)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "text.page.badge.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor.opacity(0.4))
            }

            VStack(spacing: 6) {
                Text("Ready to read later")
                    .font(.headline)
                Text("Paste a URL above or import\nyour articles from Safari")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 20) {
                emptyHint(icon: "link", text: "URL")
                emptyHint(icon: "safari", text: "Safari")
                emptyHint(icon: "doc.on.clipboard", text: "Clipboard")
            }

            Spacer()
        }
    }

    private func emptyHint(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.quaternary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Footer (glass bar)

    private var footerSection: some View {
        HStack(spacing: 0) {
            GlassFooterButton(icon: "gearshape") {
                withAnimation(.easeInOut(duration: 0.2)) { viewMode = .preferences }
            }
            GlassFooterButton(icon: "safari") { openSafariBookmarks() }

            Spacer()

            if !articles.isEmpty {
                Text("\(articles.count)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .glassPill(color: .gray)
            }

            Spacer()

            GlassFooterButton(icon: "questionmark.circle") {
                withAnimation(.easeInOut(duration: 0.2)) { viewMode = .help }
            }
            GlassFooterButton(icon: "power") { onQuit?() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Actions

    private func openSafariBookmarks() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import Safari Reading List")
        panel.message = String(localized: "Select Bookmarks.plist then click Open")
        panel.allowedContentTypes = [.propertyList]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Users/" + NSUserName() + "/Library/Safari")
        panel.nameFieldStringValue = "Bookmarks.plist"
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            withAnimation(.easeInOut(duration: 0.2)) { viewMode = .safariImport(url) }
        }
    }

    private func addArticle() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            withAnimation { errorMessage = ArticleError.invalidURL.localizedDescription }
            return
        }
        if articles.contains(where: { $0.url == trimmed }) {
            withAnimation { errorMessage = String(localized: "This URL is already in your list") }
            return
        }
        clipboardMonitor.markAsSeen(trimmed)
        Task { await performExtraction(url: url, rawURL: trimmed) }
    }

    @MainActor
    private func performExtraction(url: URL, rawURL: String) async {
        isLoading = true
        errorMessage = nil
        let article = Article(url: rawURL)
        modelContext.insert(article)
        withAnimation { urlInput = "" }
        do {
            let result = try await extractor.extract(from: url)
            article.title = result.title
            article.extractedText = result.text
            article.wordCount = result.wordCount
        } catch {
            withAnimation { errorMessage = error.localizedDescription }
        }
        withAnimation { isLoading = false }
    }
}

// MARK: - Glass Footer Button

struct GlassFooterButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.callout)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isHovered ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 0.5)
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovered ? .primary : .secondary)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovered = h } }
    }
}

// MARK: - Article Row (glass card)

struct ArticleRow: View {
    let article: Article
    @Environment(\.modelContext) private var modelContext
    @State private var isSummarizing = false
    @State private var summaryError: String?
    @State private var isExpanded = false
    @State private var isHovered = false
    @AppStorage("selectedProvider") private var selectedProvider: String = "ollama"
    @AppStorage("summaryLanguage") private var summaryLanguage: String = "français"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                siteInitial

                VStack(alignment: .leading, spacing: 3) {
                    Text(article.title)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(isExpanded ? 4 : 2)

                    Text(displayURL)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 5) {
                        Text(article.dateAdded, format: .dateTime.day().month(.abbreviated))
                        if article.wordCount > 0 {
                            Text("·")
                            Text("\(article.wordCount) words")
                        }
                        if let s = article.summary {
                            Text("·")
                            Text("~\(s.readingTime) min")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                }

                Spacer(minLength: 4)
                actionBadge
            }

            // Résumé expandé
            if let summary = article.summary, isExpanded {
                expandedSummary(summary)
                    .padding(.leading, 38)
                    .padding(.top, 10)
            }

            if let error = summaryError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 38)
                    .padding(.top, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isHovered
                                ? Color.primary.opacity(0.1)
                                : Color.primary.opacity(0.04),
                            lineWidth: 0.5
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if article.summary != nil {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }
        }
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovered = h } }
        .contextMenu { ExportMenuView(article: article) }
    }

    // MARK: - Site Initial (avatar coloré par domaine)

    private var siteInitial: some View {
        let domain = URL(string: article.url)?.host ?? "?"
        let initial = String(domain.replacingOccurrences(of: "www.", with: "").prefix(1)).uppercased()
        let hue = Double(abs(domain.hashValue) % 360) / 360.0

        return Text(initial)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: hue, saturation: 0.5, brightness: 0.8),
                                Color(hue: hue, saturation: 0.6, brightness: 0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hue: hue, saturation: 0.4, brightness: 0.5).opacity(0.3), radius: 4, y: 2)
            )
    }

    // MARK: - Action Badge

    @ViewBuilder
    private var actionBadge: some View {
        if article.summary != nil {
            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                .font(.callout)
                .foregroundStyle(isExpanded ? Color.accentColor : Color.gray.opacity(0.3))
        } else if article.extractedText == nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if isSummarizing {
            ProgressView().controlSize(.small)
        } else {
            Button { summarizeArticle() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("Summarize")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(GlassButtonStyle(color: .purple))
        }
    }

    // MARK: - Expanded Summary (glass cards)

    private func expandedSummary(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // TL;DR dans un encadré glass
            Text(summary.tldr)
                .font(.body)
                .glassCard(cornerRadius: 8, padding: 10)

            // Points clés
            if !summary.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.4))
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(point)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Tags en pills glass
            if !summary.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(summary.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .glassPill(color: .purple)
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
    }

    // MARK: - Helpers

    private var displayURL: String {
        guard let host = URL(string: article.url)?.host else { return article.url }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private func summarizeArticle() {
        guard let text = article.extractedText else { return }
        isSummarizing = true
        summaryError = nil
        Task {
            do {
                let provider: any LLMProvider = resolveProvider()
                let summary = try await provider.summarize(text: text, language: summaryLanguage)
                article.summary = summary
                article.isRead = true
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true }
            } catch { summaryError = error.localizedDescription }
            isSummarizing = false
        }
    }

    private func resolveProvider() -> any LLMProvider {
        switch selectedProvider {
        case "claude": ClaudeProvider()
        case "openai": OpenAIProvider()
        default: OllamaProvider()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Article.self, inMemory: true)
}
