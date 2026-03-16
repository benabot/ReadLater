import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ContentView

struct ContentView: View {

    enum ViewMode: Equatable {
        case articles
        case safariImport(URL)
        case preferences
        case onboarding
        case help

        static func == (lhs: ViewMode, rhs: ViewMode) -> Bool {
            switch (lhs, rhs) {
            case (.articles, .articles),
                 (.preferences, .preferences),
                 (.onboarding, .onboarding),
                 (.help, .help):
                return true
            case (.safariImport(let a), .safariImport(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Article.dateAdded, order: .reverse)
    private var articles: [Article]

    @State private var urlInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var extractor = ArticleExtractor()
    @State private var clipboardMonitor = ClipboardMonitor()
    @State private var viewMode: ViewMode = .articles
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var onQuit: (() -> Void)?

    var body: some View {
        ZStack {
            switch viewMode {
            case .articles:
                articlesView
                    .transition(.opacity)
            case .safariImport(let url):
                SafariImportView(
                    bookmarksFileURL: url,
                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = .articles } }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .preferences:
                PreferencesView(
                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = .articles } }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .onboarding:
                OnboardingView(
                    onDismiss: {
                        hasSeenOnboarding = true
                        withAnimation(.easeInOut(duration: 0.3)) { viewMode = .articles }
                    }
                )
                .transition(.opacity)
            case .help:
                HelpView(
                    onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { viewMode = .articles } }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: 400, height: 540)
        .task { clipboardMonitor.start() }
        .onAppear {
            if !hasSeenOnboarding { viewMode = .onboarding }
        }
    }

    // MARK: - Articles View

    private var articlesView: some View {
        VStack(spacing: 0) {
            headerSection
            
            if let detected = clipboardMonitor.detectedURL {
                clipboardBanner(url: detected)
            }

            articleListSection

            footerSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "link.badge.plus")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("Coller ou saisir une URL…", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit { addArticle() }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button { addArticle() } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(urlInput.isEmpty ? Color.gray.opacity(0.2) : Color.accentColor)
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if let errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(errorMessage)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
        }
    }

    // MARK: - Clipboard Banner

    private func clipboardBanner(url: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.callout)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text("URL détectée")
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
                    Text("Ajouter")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

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
            .background(Color.blue.opacity(0.06))

            Divider()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Article List

    private var articleListSection: some View {
        Group {
            if articles.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(articles) { article in
                            ArticleRow(article: article)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icône stylisée
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 72, height: 72)

                Image(systemName: "text.page.badge.magnifyingglass")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor.opacity(0.5))
            }

            VStack(spacing: 6) {
                Text("Prêt à lire plus tard")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Collez une URL ci-dessus ou importez\nvos articles depuis Safari")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Raccourci visuel
            HStack(spacing: 16) {
                emptyStateHint(icon: "link", text: "Coller une URL")
                emptyStateHint(icon: "safari", text: "Import Safari")
                emptyStateHint(icon: "doc.on.clipboard", text: "Auto-détection")
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func emptyStateHint(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                FooterButton(icon: "gearshape", tooltip: "Préférences") {
                    withAnimation(.easeInOut(duration: 0.2)) { viewMode = .preferences }
                }
                FooterButton(icon: "safari", tooltip: "Import Safari") {
                    openSafariBookmarks()
                }

                Spacer()

                if !articles.isEmpty {
                    Text("\(articles.count) article\(articles.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }

                Spacer()

                FooterButton(icon: "questionmark.circle", tooltip: "Aide") {
                    withAnimation(.easeInOut(duration: 0.2)) { viewMode = .help }
                }
                FooterButton(icon: "power", tooltip: "Quitter") {
                    onQuit?()
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions

    private func openSafariBookmarks() {
        let panel = NSOpenPanel()
        panel.title = "Importer la Reading List Safari"
        panel.message = "Sélectionnez Bookmarks.plist puis cliquez Open"
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
            withAnimation { errorMessage = "Cette URL est déjà dans votre liste" }
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

    private func deleteArticles(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(articles[index]) }
    }
}

// MARK: - Footer Button

struct FooterButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.callout)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovered ? .primary : .secondary)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .help(tooltip)
    }
}

// MARK: - Article Row

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
            HStack(alignment: .top, spacing: 10) {
                // Initiale du domaine — identité visuelle de la source
                siteInitial

                VStack(alignment: .leading, spacing: 4) {
                    // Titre
                    Text(article.title)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(isExpanded ? 4 : 2)
                        .foregroundStyle(.primary)

                    // Domaine
                    Text(displayURL)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    // Métadonnées
                    HStack(spacing: 5) {
                        Text(article.dateAdded, format: .dateTime.day().month(.abbreviated))
                            .foregroundStyle(.quaternary)

                        if article.wordCount > 0 {
                            Text("·").foregroundStyle(.quaternary)
                            Text("\(article.wordCount) mots").foregroundStyle(.quaternary)
                        }

                        if let summary = article.summary {
                            Text("·").foregroundStyle(.quaternary)
                            Text("~\(summary.readingTime) min").foregroundStyle(.quaternary)
                        }
                    }
                    .font(.caption2)
                }

                Spacer(minLength: 4)

                // Action badge
                actionBadge
            }

            // Résumé expandé
            if let summary = article.summary, isExpanded {
                expandedSummary(summary)
                    .padding(.leading, 42) // Aligné avec le contenu (après l'initiale)
                    .padding(.top, 8)
            }

            // Erreur
            if let error = summaryError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.leading, 42)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if article.summary != nil {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
        .contextMenu { ExportMenuView(article: article) }
    }

    // MARK: - Site Initial

    /// Affiche la première lettre du domaine dans un cercle coloré.
    /// Donne une identité visuelle à chaque source (comme les avatars dans Mail).
    private var siteInitial: some View {
        let domain = URL(string: article.url)?.host ?? "?"
        let initial = String(domain.replacingOccurrences(of: "www.", with: "").prefix(1)).uppercased()
        // Couleur déterministe basée sur le hash du domaine
        let hue = Double(abs(domain.hashValue) % 360) / 360.0

        return Text(initial)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color(hue: hue, saturation: 0.5, brightness: 0.7))
            )
    }

    // MARK: - Action Badge

    @ViewBuilder
    private var actionBadge: some View {
        if article.summary != nil {
            // Résumé disponible — indicateur compact
            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                .font(.callout)
                .foregroundStyle(isExpanded ? Color.accentColor : Color.gray.opacity(0.4))
        } else if article.extractedText == nil {
            // Extraction échouée
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .help("Contenu non extrait")
        } else if isSummarizing {
            ProgressView()
                .controlSize(.small)
        } else {
            // Bouton résumer
            Button { summarizeArticle() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("Résumer")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.12))
                .foregroundStyle(.purple)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Expanded Summary

    private func expandedSummary(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // TL;DR dans un encadré
            Text(summary.tldr)
                .font(.callout)
                .foregroundStyle(.primary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
                        )
                )

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
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Tags
            if !summary.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(summary.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.medium)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
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
            } catch {
                summaryError = error.localizedDescription
            }
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
