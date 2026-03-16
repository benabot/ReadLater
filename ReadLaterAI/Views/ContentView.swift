import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ContentView
// Vue principale du popover avec navigation inline.

struct ContentView: View {

    enum ViewMode {
        case articles
        case safariImport(URL)
        case preferences
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

    var onQuit: (() -> Void)?

    var body: some View {
        Group {
            switch viewMode {
            case .articles:
                articlesView
            case .safariImport(let url):
                SafariImportView(
                    bookmarksFileURL: url,
                    onDismiss: { withAnimation { viewMode = .articles } }
                )
            case .preferences:
                PreferencesView(
                    onDismiss: { withAnimation { viewMode = .articles } }
                )
            }
        }
        .frame(width: 380, height: 520)
        .task { clipboardMonitor.start() }
    }

    // MARK: - Articles View

    private var articlesView: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if let detected = clipboardMonitor.detectedURL {
                clipboardBanner(url: detected)
            }

            articleListSection

            Divider()
            footerSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TextField("Coller ou saisir une URL…", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .default))
                    .onSubmit { addArticle() }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        addArticle()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(urlInput.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if let errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption2)
                    Text(errorMessage)
                        .font(.caption2)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(10)
    }

    // MARK: - Clipboard Banner

    private func clipboardBanner(url: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.caption)
                .foregroundStyle(.blue)

            Text(url)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                urlInput = url
                clipboardMonitor.clearDetectedURL()
                addArticle()
            } label: {
                Text("Ajouter")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Button {
                clipboardMonitor.clearDetectedURL()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.05))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Article List

    private var articleListSection: some View {
        Group {
            if articles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.page")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("Aucun article")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Collez une URL ou importez depuis Safari")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(articles) { article in
                            ArticleRow(article: article)
                            if article.id != articles.last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 12) {
            // Boutons d'action à gauche
            HStack(spacing: 2) {
                FooterButton(icon: "gearshape", label: nil) {
                    withAnimation { viewMode = .preferences }
                }

                FooterButton(icon: "safari", label: nil) {
                    openSafariBookmarks()
                }
            }

            Spacer()

            if !articles.isEmpty {
                Text("\(articles.count)")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            FooterButton(icon: "power", label: nil) {
                onQuit?()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
            withAnimation { viewMode = .safariImport(url) }
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
    let label: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                if let label {
                    Text(label)
                        .font(.caption)
                }
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Article Row

struct ArticleRow: View {
    let article: Article
    @Environment(\.modelContext) private var modelContext
    @State private var isSummarizing = false
    @State private var summaryError: String?
    @State private var isExpanded = false
    @AppStorage("selectedProvider") private var selectedProvider: String = "ollama"
    @AppStorage("summaryLanguage") private var summaryLanguage: String = "français"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Titre + bouton actions
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.system(.subheadline, weight: .medium))
                        .lineLimit(isExpanded ? 4 : 1)

                    Text(displayURL)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Badges & actions
                HStack(spacing: 6) {
                    if article.summary != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else if article.extractedText == nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else if isSummarizing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Button { summarizeArticle() } label: {
                            Image(systemName: "sparkles")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.purple)
                        .help("Résumer avec l'IA")
                    }
                }
            }

            // Métadonnées
            HStack(spacing: 6) {
                Text(article.dateAdded, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.quaternary)

                if article.wordCount > 0 {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text("\(article.wordCount) mots")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }

                if let summary = article.summary {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text("~\(summary.readingTime) min")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }

            // Résumé expandé
            if let summary = article.summary, isExpanded {
                expandedSummary(summary)
            }

            // Erreur
            if let error = summaryError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if article.summary != nil {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }
        }
        .contextMenu { ExportMenuView(article: article) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { modelContext.delete(article) }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    // MARK: - Résumé expandé

    private func expandedSummary(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // TL;DR
            Text(summary.tldr)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Points clés
            if !summary.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(summary.keyPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(.secondary)
                                .frame(width: 4, height: 4)
                                .padding(.top, 5)
                            Text(point)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Tags
            if !summary.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(summary.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(.caption2, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    /// Extrait le domaine de l'URL pour affichage compact
    private var displayURL: String {
        URL(string: article.url)?.host ?? article.url
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
                withAnimation { isExpanded = true }
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
