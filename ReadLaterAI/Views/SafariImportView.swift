import SwiftUI
import SwiftData

// MARK: - SafariImportView
// Vue inline (PAS un sheet) qui remplace le contenu du popover
// pour afficher les articles de la Safari Reading List.
//
// On évite les .sheet dans un popover MenuBarExtra car ils provoquent
// la fermeture du popover au clic — un bug macOS connu.

struct SafariImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var existingArticles: [Article]

    @State private var items: [SafariImporter.ReadingListItem] = []
    @State private var selectedIDs: Set<UUID> = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var importer = SafariImporter()

    let bookmarksFileURL: URL
    /// Callback pour revenir à la vue articles (remplace dismiss())
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Importer depuis Safari", systemImage: "safari")
                    .font(.headline)
                Spacer()
                Button("Retour") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            Divider()

            // Contenu
            if isLoading {
                ProgressView("Lecture de la Reading List…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Erreur", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ContentUnavailableView {
                    Label("Aucun article", systemImage: "tray")
                } description: {
                    Text("Votre Reading List Safari est vide")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                itemListView
            }

            Divider()
            bottomBar
        }
        .task {
            await loadReadingList()
        }
    }

    // MARK: - Liste

    private var itemListView: some View {
        List {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    // Checkbox
                    Button {
                        toggleSelection(item.id)
                    } label: {
                        Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIDs.contains(item.id) ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.body)
                            .lineLimit(1)

                        Text(item.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let preview = item.previewText, !preview.isEmpty {
                            Text(preview)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }

                        if isAlreadyImported(url: item.url) {
                            Label("Déjà importé", systemImage: "checkmark.circle")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Barre du bas

    private var bottomBar: some View {
        HStack {
            if isImporting {
                ProgressView(value: Double(importProgress), total: Double(max(importTotal, 1)))
                    .frame(width: 80)
                Text("\(importProgress)/\(importTotal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Tout") {
                    selectedIDs = Set(items.map(\.id))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button("Aucun") {
                    selectedIDs.removeAll()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(selectedIDs.count) sélectionné\(selectedIDs.count > 1 ? "s" : "")")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Importer") {
                importSelected()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedIDs.isEmpty || isImporting)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func loadReadingList() async {
        isLoading = true
        errorMessage = nil

        do {
            items = try await importer.importReadingList(from: bookmarksFileURL)
            selectedIDs = Set(
                items.filter { !isAlreadyImported(url: $0.url) }.map(\.id)
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @State private var extractor = ArticleExtractor()
    @State private var importProgress: Int = 0
    @State private var importTotal: Int = 0
    @State private var isImporting: Bool = false

    private func importSelected() {
        let selectedItems = items.filter { selectedIDs.contains($0.id) }
            .filter { !isAlreadyImported(url: $0.url) }

        guard !selectedItems.isEmpty else {
            onDismiss()
            return
        }

        // Insérer tous les articles en base immédiatement
        var insertedArticles: [(Article, URL)] = []
        for item in selectedItems {
            let article = Article(url: item.url, title: item.title)
            modelContext.insert(article)
            if let url = URL(string: item.url) {
                insertedArticles.append((article, url))
            }
        }

        // Lancer l'extraction séquentiellement pour chaque article.
        // On fait ça en séquentiel (pas en parallèle) car :
        // 1. Les @Model (Article) sont @MainActor-isolated, on ne peut pas
        //    les envoyer dans une TaskGroup (Swift 6 strict concurrency)
        // 2. C'est plus simple et évite de surcharger le réseau
        importTotal = insertedArticles.count
        importProgress = 0
        isImporting = true

        Task {
            for (article, url) in insertedArticles {
                do {
                    let result = try await extractor.extract(from: url)
                    article.title = result.title
                    article.extractedText = result.text
                    article.wordCount = result.wordCount
                } catch {
                    // L'extraction a échoué — l'article garde le titre Safari.
                    // Le triangle ⚠️ sera affiché dans la liste.
                }
                importProgress += 1
            }

            isImporting = false
            onDismiss()
        }
    }

    private func isAlreadyImported(url: String) -> Bool {
        existingArticles.contains { $0.url == url }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}
