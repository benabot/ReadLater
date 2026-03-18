import AppKit
import Foundation

// MARK: - ExportService
// Service d'export d'articles vers différentes apps de notes.
//
// Chaque app a sa propre méthode d'intégration :
// - URL schemes (bear://, ia-writer://, obsidian://, craftdocs://, ulysses://)
// - NSSharingService (Notes)
// - NSPasteboard (Clipboard)
//
// Les URL schemes sont le mécanisme macOS pour communiquer entre apps.
// C'est comme les "deep links" sur mobile ou les `window.open("myapp://...")` en web.

enum ExportService {

    // MARK: - Erreurs

    enum ExportError: LocalizedError {
        case noContent
        case appNotInstalled(String)
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noContent:
                String(localized: "No content to export (summary or text missing)")
            case .appNotInstalled(let app):
                String(localized: "\(app) does not seem to be installed on this Mac")
            case .exportFailed(let detail):
                String(localized: "Export error: \(detail)")
            }
        }
    }

    // MARK: - Cibles d'export

    enum Target: String, CaseIterable, Identifiable {
        case bear
        case iaWriter
        case obsidian
        case craft
        case ulysses
        case evernote
        case notes
        case clipboard

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .bear: "Bear"
            case .iaWriter: "iA Writer"
            case .obsidian: "Obsidian"
            case .craft: "Craft"
            case .ulysses: "Ulysses"
            case .evernote: "Evernote"
            case .notes: "Notes"
            case .clipboard: String(localized: "Copy as Markdown")
            }
        }

        var icon: String {
            switch self {
            case .bear: "text.book.closed"
            case .iaWriter: "doc.text"
            case .obsidian: "diamond"
            case .craft: "doc.richtext"
            case .ulysses: "text.justify.leading"
            case .evernote: "elephant" // fallback SF Symbol
            case .notes: "note.text"
            case .clipboard: "doc.on.doc"
            }
        }
    }

    // MARK: - Export principal

    @MainActor
    static func export(_ article: Article, to target: Target) throws {
        let markdown = generateMarkdown(for: article)

        guard !markdown.isEmpty else {
            throw ExportError.noContent
        }

        switch target {
        case .bear:
            try exportToBear(article: article, markdown: markdown)
        case .iaWriter:
            try exportToIAWriter(markdown: markdown)
        case .obsidian:
            try exportToObsidian(article: article, markdown: markdown)
        case .craft:
            try exportToCraft(markdown: markdown)
        case .ulysses:
            try exportToUlysses(markdown: markdown)
        case .evernote:
            try exportToEvernote(article: article, markdown: markdown)
        case .notes:
            exportToNotes(markdown: markdown)
        case .clipboard:
            copyToClipboard(markdown: markdown)
        }
    }

    // MARK: - Génération Markdown

    static func generateMarkdown(for article: Article) -> String {
        var lines: [String] = []

        lines.append("# \(article.title)")
        lines.append("")
        lines.append("> Source : [\(article.url)](\(article.url))")
        lines.append("")

        if let summary = article.summary {
            lines.append("## \(String(localized: "Summary"))")
            lines.append("")
            lines.append(summary.tldr)
            lines.append("")

            if !summary.keyPoints.isEmpty {
                lines.append("## \(String(localized: "Key points"))")
                lines.append("")
                for point in summary.keyPoints {
                    lines.append("- \(point)")
                }
                lines.append("")
            }

            lines.append("**\(String(localized: "Estimated reading time"))** : \(summary.readingTime) min")
            lines.append("")

            if !summary.tags.isEmpty {
                let tagsString = summary.tags.map { "#\($0)" }.joined(separator: " ")
                lines.append("**\(String(localized: "Tags"))** : \(tagsString)")
                lines.append("")
            }
        } else if let text = article.extractedText {
            let preview = String(text.prefix(2000))
            lines.append(preview)
            if text.count > 2000 {
                lines.append("")
                lines.append("*[Texte tronqué — \(article.wordCount) mots au total]*")
            }
            lines.append("")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        lines.append("---")
        let dateStr = formatter.string(from: article.dateAdded)
        lines.append("*\(String(localized: "Saved on \(dateStr) via ReadLater AI"))*")

        return lines.joined(separator: "\n")
    }

    // MARK: - Bear
    // bear://x-callback-url/create?title=...&text=...&tags=readlater

    @MainActor
    private static func exportToBear(article: Article, markdown: String) throws {
        var components = URLComponents(string: "bear://x-callback-url/create")!

        // Construire les tags : "readlater" + tags du résumé
        var tags = ["readlater"]
        if let summary = article.summary {
            tags.append(contentsOf: summary.tags)
        }

        components.queryItems = [
            URLQueryItem(name: "title", value: article.title),
            URLQueryItem(name: "text", value: markdown),
            URLQueryItem(name: "tags", value: tags.joined(separator: ","))
        ]

        guard let url = components.url else {
            throw ExportError.exportFailed("Impossible de construire l'URL Bear")
        }

        guard NSWorkspace.shared.open(url) else {
            throw ExportError.appNotInstalled("Bear")
        }
    }

    // MARK: - iA Writer
    // ia-writer://new?text=...

    @MainActor
    private static func exportToIAWriter(markdown: String) throws {
        var components = URLComponents(string: "ia-writer://new")!
        components.queryItems = [
            URLQueryItem(name: "text", value: markdown)
        ]

        guard let url = components.url else {
            throw ExportError.exportFailed("Impossible de construire l'URL iA Writer")
        }

        guard NSWorkspace.shared.open(url) else {
            throw ExportError.appNotInstalled("iA Writer")
        }
    }

    // MARK: - Obsidian
    // obsidian://new?vault=...&name=...&content=...
    //
    // Obsidian est un éditeur Markdown qui stocke ses notes dans un "vault"
    // (un dossier local). L'URL scheme crée un nouveau fichier .md dans le vault.
    // Si aucun vault n'est spécifié, Obsidian utilise le vault par défaut.

    @MainActor
    private static func exportToObsidian(article: Article, markdown: String) throws {
        var components = URLComponents(string: "obsidian://new")!

        // Nettoyer le titre pour en faire un nom de fichier valide
        let cleanTitle = article.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: " -")

        components.queryItems = [
            URLQueryItem(name: "name", value: cleanTitle),
            URLQueryItem(name: "content", value: markdown)
        ]

        guard let url = components.url else {
            throw ExportError.exportFailed("Impossible de construire l'URL Obsidian")
        }

        guard NSWorkspace.shared.open(url) else {
            throw ExportError.appNotInstalled("Obsidian")
        }
    }

    // MARK: - Craft
    // craftdocs://createdocument?spaceId=...&title=...&content=...
    //
    // Craft est une app de notes structurée. Son URL scheme permet de créer
    // un document dans l'espace par défaut. Le contenu supporte le Markdown.

    @MainActor
    private static func exportToCraft(markdown: String) throws {
        var components = URLComponents(string: "craftdocs://createdocument")!
        components.queryItems = [
            URLQueryItem(name: "content", value: markdown),
            URLQueryItem(name: "folderId", value: "")  // dossier racine
        ]

        guard let url = components.url else {
            throw ExportError.exportFailed("Impossible de construire l'URL Craft")
        }

        guard NSWorkspace.shared.open(url) else {
            throw ExportError.appNotInstalled("Craft")
        }
    }

    // MARK: - Ulysses
    // ulysses://x-callback-url/new-sheet?text=...
    //
    // Ulysses est un éditeur d'écriture longue. Son URL scheme crée une
    // nouvelle "feuille" (sheet) avec le contenu Markdown.

    @MainActor
    private static func exportToUlysses(markdown: String) throws {
        var components = URLComponents(string: "ulysses://x-callback-url/new-sheet")!
        components.queryItems = [
            URLQueryItem(name: "text", value: markdown)
        ]

        guard let url = components.url else {
            throw ExportError.exportFailed("Impossible de construire l'URL Ulysses")
        }

        guard NSWorkspace.shared.open(url) else {
            throw ExportError.appNotInstalled("Ulysses")
        }
    }

    // MARK: - Evernote
    // evernote://x-callback-url/new-note?title=...&text=...&tags=readlater
    //
    // L'URL scheme Evernote est legacy mais fonctionne encore.
    // Evernote attend du HTML dans le champ "text", pas du Markdown.

    @MainActor
    private static func exportToEvernote(article: Article, markdown: String) throws {
        var components = URLComponents(string: "evernote://x-callback-url/new-note")!

        // Evernote préfère du texte brut dans les URL schemes.
        // On envoie le Markdown tel quel — Evernote le gardera en texte.
        components.queryItems = [
            URLQueryItem(name: "title", value: article.title),
            URLQueryItem(name: "text", value: markdown),
            URLQueryItem(name: "tags", value: "readlater")
        ]

        guard let url = components.url else {
            throw ExportError.exportFailed("Impossible de construire l'URL Evernote")
        }

        guard NSWorkspace.shared.open(url) else {
            throw ExportError.appNotInstalled("Evernote")
        }
    }

    // MARK: - Notes (Apple)
    // Lance osascript en process externe pour créer une note dans Notes.
    // NSAppleScript ne fonctionne pas en sandbox, mais Process + osascript oui
    // car osascript tourne hors de la sandbox de l'app.
    //
    // C'est l'équivalent de `child_process.exec('osascript ...')` en Node.js.

    @MainActor
    private static func exportToNotes(markdown: String) {
        // Escape pour AppleScript : backslashes puis guillemets
        let escaped = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "tell application \"Notes\" to make new note at folder \"Notes\" with properties {body:\"\(escaped)\"}"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, "-e", "tell application \"Notes\" to activate"]

        do {
            try process.run()
        } catch {
            // Fallback : copier dans le clipboard
            copyToClipboard(markdown: markdown)
        }
    }

    // MARK: - Clipboard

    static func copyToClipboard(markdown: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }
}
