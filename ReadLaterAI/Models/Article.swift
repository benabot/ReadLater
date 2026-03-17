import Foundation
import SwiftData

// MARK: - Summary
// Structure encodable pour stocker le résumé LLM dans SwiftData.
// SwiftData ne peut pas stocker directement un struct custom,
// donc on le transforme en Data via Codable (comme JSON.stringify en JS).

struct Summary: Codable, Hashable, Sendable {
    let tldr: String            // 2-3 phrases de résumé
    let keyPoints: [String]     // 3-5 bullet points
    let readingTime: Int        // minutes estimées
    let tags: [String]          // 3-5 tags auto-générés
}

// MARK: - Article Model
// @Model est le décorateur SwiftData (équivalent d'un schéma Mongoose ou d'un modèle Eloquent).
// Il génère automatiquement la persistance SQLite sous le capot.
// Chaque propriété `var` devient une colonne persistée.

@Model
final class Article {
    // @Attribute(.unique) garantit l'unicité en base, comme une contrainte UNIQUE en SQL.
    @Attribute(.unique) var id: UUID

    var url: String
    var title: String

    // Les données binaires (Data) permettent de stocker un JSON encodé.
    // On utilise un "computed property" plus bas pour accéder au Summary typé.
    var summaryData: Data?

    var dateAdded: Date
    var isRead: Bool
    var wordCount: Int
    var extractedText: String?

    // MARK: - Init
    init(url: String, title: String = "") {
        self.id = UUID()
        self.url = url
        self.title = title.isEmpty ? url : title
        self.dateAdded = Date()
        self.isRead = false
        self.wordCount = 0
    }

    // MARK: - Summary (computed)
    // Propriété calculée pour encoder/décoder le Summary.
    // SwiftData persiste `summaryData` (Data), et on expose `summary` (Summary?).
    // C'est comme un getter/setter en JS :
    //   get summary() { return JSON.parse(this.summaryData) }
    //   set summary(val) { this.summaryData = JSON.stringify(val) }

    @Transient  // @Transient = ne pas persister cette propriété, elle est calculée
    var summary: Summary? {
        get {
            guard let data = summaryData else { return nil }
            return try? JSONDecoder().decode(Summary.self, from: data)
        }
        set {
            summaryData = try? JSONEncoder().encode(newValue)
        }
    }
}

// MARK: - ArticleError
// Enum d'erreur typé. En Swift, on modélise les erreurs comme des enums
// (plutôt que des classes comme en JS). Chaque case = un type d'erreur précis.
// `LocalizedError` permet de fournir un message lisible via `errorDescription`.

enum ArticleError: LocalizedError {
    case invalidURL
    case networkTimeout
    case emptyContent
    case parsingFailed(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "The provided URL is not valid")
        case .networkTimeout:
            String(localized: "The request timed out (10s timeout)")
        case .emptyContent:
            String(localized: "No usable content found")
        case .parsingFailed(let detail):
            String(localized: "Parsing error: \(detail)")
        case .saveFailed(let detail):
            String(localized: "Save error: \(detail)")
        }
    }
}
