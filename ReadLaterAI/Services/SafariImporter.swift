import Foundation

// MARK: - SafariImporter
// Service qui lit la Safari Reading List pour permettre à l'utilisateur
// d'importer ses articles "à lire plus tard" depuis Safari.
//
// Safari stocke sa Reading List dans ~/Library/Safari/Bookmarks.plist.
// C'est un fichier plist (Property List) — le format de sérialisation natif d'Apple.
// Un plist est l'équivalent Apple d'un JSON : il peut contenir des dictionnaires,
// tableaux, strings, dates, etc. mais dans un format binaire ou XML.
//
// IMPORTANT SANDBOX :
// En mode sandboxé (App Store), l'accès à ~/Library/Safari/ est INTERDIT.
// Ce service fonctionnera uniquement en mode développement (sans sandbox)
// ou si l'utilisateur accorde explicitement l'accès via un NSOpenPanel.
// On gère ce cas avec une erreur explicite.

actor SafariImporter {

    // MARK: - ReadingListItem

    /// Représente un article de la Safari Reading List.
    /// Sendable car on le passe entre l'actor et le @MainActor (la vue).
    struct ReadingListItem: Sendable, Identifiable {
        let id: UUID = UUID()
        let title: String
        let url: String
        let dateAdded: Date?
        let previewText: String?
    }

    // MARK: - Erreurs

    enum SafariImportError: LocalizedError {
        case fileNotFound
        case sandboxRestriction
        case parsingFailed(String)
        case noReadingListItems

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                String(localized: "Safari Bookmarks.plist file not found")
            case .sandboxRestriction:
                String(localized: "The app is sandboxed and cannot access the Safari folder. Click below to select ~/Library/Safari/Bookmarks.plist manually.")
            case .parsingFailed(let detail):
                String(localized: "Unable to read the Reading List: \(detail)")
            case .noReadingListItems:
                String(localized: "No articles found in Safari Reading List")
            }
        }
    }

    // MARK: - Import principal

    /// Lit la Safari Reading List et retourne les articles.
    ///
    /// Le fichier Bookmarks.plist a cette structure (simplifiée) :
    /// ```
    /// {
    ///   "Children": [
    ///     {
    ///       "Title": "com.apple.ReadingList",
    ///       "Children": [
    ///         {
    ///           "URIDictionary": { "title": "Mon article" },
    ///           "URLString": "https://example.com/article",
    ///           "ReadingList": {
    ///             "DateAdded": 2024-01-15T10:30:00Z,
    ///             "PreviewText": "Début de l'article..."
    ///           }
    ///         },
    ///         ...
    ///       ]
    ///     }
    ///   ]
    /// }
    /// ```
    ///
    /// - Parameter fileURL: Chemin vers le fichier Bookmarks.plist.
    ///   Si nil, utilise le chemin par défaut ~/Library/Safari/Bookmarks.plist
    /// - Returns: Liste d'articles de la Reading List.
    func importReadingList(from fileURL: URL? = nil) async throws -> [ReadingListItem] {
        let bookmarksURL = try resolveBookmarksURL(fileURL)
        let plistData = try loadPlistData(from: bookmarksURL)
        let items = try extractReadingListItems(from: plistData)

        guard !items.isEmpty else {
            throw SafariImportError.noReadingListItems
        }

        return items
    }

    // MARK: - Résolution du chemin

    /// Détermine le chemin du fichier Bookmarks.plist.
    ///
    /// FileManager est la classe Apple pour manipuler le système de fichiers.
    /// C'est l'équivalent du module `fs` en Node.js.
    private func resolveBookmarksURL(_ override: URL?) throws -> URL {
        if let override {
            // L'utilisateur a fourni un chemin explicite (via NSOpenPanel par exemple)
            guard FileManager.default.fileExists(atPath: override.path) else {
                throw SafariImportError.fileNotFound
            }
            return override
        }

        // Chemin par défaut de Safari Reading List.
        // FileManager.default.homeDirectoryForCurrentUser retourne :
        //   - SANS sandbox : /Users/benoitabot
        //   - AVEC sandbox : ~/Library/Containers/com.benoitabot.ReadLaterAI/Data
        // Donc en sandbox, ce chemin pointe vers le mauvais endroit.
        //
        // On tente d'abord le vrai chemin (hors sandbox), puis on détecte la sandbox.
        let realHomePath = "/Users/" + NSUserName()
        let bookmarksPath = URL(fileURLWithPath: realHomePath)
            .appendingPathComponent("Library")
            .appendingPathComponent("Safari")
            .appendingPathComponent("Bookmarks.plist")

        // Tester si le fichier est lisible (pas juste s'il "existe").
        // En sandbox, FileManager.fileExists retourne false même si le fichier
        // existe réellement, car l'app n'a pas la permission de le voir.
        guard FileManager.default.isReadableFile(atPath: bookmarksPath.path) else {
            // En sandbox, on ne peut pas accéder à ~/Library/Safari/
            // → proposer la sélection manuelle via NSOpenPanel
            throw SafariImportError.sandboxRestriction
        }

        return bookmarksPath
    }

    // MARK: - Lecture du plist

    /// Charge et décode le fichier plist en dictionnaire Swift.
    ///
    /// PropertyListSerialization est la classe Apple pour lire les fichiers plist.
    /// C'est comme JSON.parse() mais pour le format plist (binaire ou XML).
    /// On obtient un `Any` (le type "fourre-tout" de Swift, comme `any` en TypeScript)
    /// qu'il faut ensuite caster en types précis.
    private func loadPlistData(from url: URL) throws -> [String: Any] {
        let data: Data
        do {
            // Data(contentsOf:) lit le fichier en mémoire.
            // C'est comme fs.readFileSync() en Node.js.
            data = try Data(contentsOf: url)
        } catch {
            throw SafariImportError.parsingFailed("Impossible de lire le fichier : \(error.localizedDescription)")
        }

        // Décoder le plist en objet Swift.
        // Le résultat est un `Any` qu'on caste en [String: Any] (dictionnaire).
        // `as?` est un cast conditionnel : retourne nil si le cast échoue.
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw SafariImportError.parsingFailed("Format plist invalide")
        }

        return plist
    }

    // MARK: - Extraction des items Reading List

    /// Parcourt la structure du plist pour trouver les entrées Reading List.
    ///
    /// La structure est arborescente : on cherche le nœud "com.apple.ReadingList"
    /// dans les Children du dictionnaire racine, puis on itère sur ses propres Children.
    private func extractReadingListItems(from plist: [String: Any]) throws -> [ReadingListItem] {
        // Trouver le nœud racine "Children"
        guard let children = plist["Children"] as? [[String: Any]] else {
            throw SafariImportError.parsingFailed("Structure Children manquante")
        }

        // Chercher le nœud "com.apple.ReadingList" parmi les enfants.
        // .first(where:) est l'équivalent de Array.find() en JS.
        guard let readingListNode = children.first(where: { node in
            (node["Title"] as? String) == "com.apple.ReadingList"
        }) else {
            throw SafariImportError.noReadingListItems
        }

        // Extraire les articles de la Reading List
        guard let readingListChildren = readingListNode["Children"] as? [[String: Any]] else {
            throw SafariImportError.noReadingListItems
        }

        // .compactMap() est comme .map().filter(x => x !== null) en JS.
        // Il transforme chaque élément ET supprime les nil du résultat.
        let items = readingListChildren.compactMap { entry -> ReadingListItem? in
            parseReadingListEntry(entry)
        }

        return items
    }

    // MARK: - Parsing d'une entrée individuelle

    /// Parse un dictionnaire plist en ReadingListItem.
    ///
    /// Retourne nil si les données essentielles (url) sont manquantes.
    /// C'est un pattern courant en Swift : une fonction qui retourne un Optional
    /// pour signaler "je n'ai pas pu parser cet élément" sans lever d'erreur.
    private func parseReadingListEntry(_ entry: [String: Any]) -> ReadingListItem? {
        // L'URL est stockée dans "URLString"
        guard let urlString = entry["URLString"] as? String,
              !urlString.isEmpty else {
            return nil
        }

        // Le titre est dans URIDictionary.title
        let uriDict = entry["URIDictionary"] as? [String: Any]
        let title = uriDict?["title"] as? String ?? urlString

        // Les métadonnées Reading List sont dans le sous-dictionnaire "ReadingList"
        let readingListDict = entry["ReadingList"] as? [String: Any]
        let dateAdded = readingListDict?["DateAdded"] as? Date
        let previewText = readingListDict?["PreviewText"] as? String

        return ReadingListItem(
            title: title,
            url: urlString,
            dateAdded: dateAdded,
            previewText: previewText
        )
    }
}
