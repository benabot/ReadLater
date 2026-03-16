import Foundation
import SwiftSoup

// MARK: - ArticleExtractor
// Service responsable de :
// 1. Télécharger le HTML d'une URL (via URLSession async/await)
// 2. Parser le HTML avec SwiftSoup pour extraire titre + contenu texte
//
// C'est un "actor" Swift. Un actor est un type reference (comme une class)
// qui protège automatiquement son état interne contre les accès concurrents.
// Imagine un objet JS avec un mutex intégré : deux appels simultanés ne peuvent
// pas corrompre les données internes.
//
// Analogie web : c'est comme un service singleton en Angular ou un composable
// en Vue, mais avec la garantie que les accès concurrents sont sérialisés.

actor ArticleExtractor {

    // MARK: - Configuration

    private let timeoutInterval: TimeInterval = 10

    /// User-Agent pour se faire passer pour un navigateur classique.
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    // MARK: - Résultat d'extraction

    /// Structure retournée après extraction réussie.
    /// Sendable = peut être envoyé entre actors/threads en toute sécurité.
    struct ExtractionResult: Sendable {
        let title: String
        let text: String
        let wordCount: Int
    }

    // MARK: - Extraction principale

    /// Télécharge et parse une URL pour en extraire le contenu.
    /// `async throws` = une Promise qui peut reject en JS.
    func extract(from url: URL) async throws -> ExtractionResult {
        let html = try await fetchHTML(from: url)
        let result = try parseHTML(html, sourceURL: url)
        return result
    }

    // MARK: - Fetch HTML

    /// Télécharge le contenu HTML d'une URL.
    /// URLSession est le client HTTP natif d'Apple (≈ fetch() en JS).
    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ArticleError.networkTimeout
        } catch {
            throw ArticleError.parsingFailed("Erreur réseau : \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ArticleError.parsingFailed("HTTP \(statusCode)")
        }

        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw ArticleError.parsingFailed("Encodage du contenu non supporté")
        }

        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ArticleError.emptyContent
        }

        return html
    }

    // MARK: - Parse HTML avec SwiftSoup

    /// Extrait le titre et le contenu textuel d'un document HTML.
    /// SwiftSoup API ≈ jQuery : doc.select("article") ≈ $("article")
    private func parseHTML(_ html: String, sourceURL: URL) throws -> ExtractionResult {
        let doc: Document
        do {
            doc = try SwiftSoup.parse(html, sourceURL.absoluteString)
        } catch {
            throw ArticleError.parsingFailed("Impossible de parser le HTML")
        }

        let title = extractTitle(from: doc)
        removeNoise(from: doc)
        let text = extractMainContent(from: doc)

        guard !text.isEmpty else {
            throw ArticleError.emptyContent
        }

        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count

        return ExtractionResult(title: title, text: text, wordCount: wordCount)
    }

    // MARK: - Extraction du titre

    /// Essaie plusieurs sources pour trouver le meilleur titre.
    private func extractTitle(from doc: Document) -> String {
        // Priorité 1 : Open Graph (og:title)
        if let ogTitle = try? doc.select("meta[property=og:title]").first()?.attr("content"),
           !ogTitle.isEmpty {
            return ogTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Priorité 2 : Twitter Card title
        if let twitterTitle = try? doc.select("meta[name=twitter:title]").first()?.attr("content"),
           !twitterTitle.isEmpty {
            return twitterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Priorité 3 : premier <h1>
        if let h1 = try? doc.select("h1").first()?.text(),
           !h1.isEmpty {
            return h1.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Priorité 4 : <title> (souvent contient le nom du site)
        if let title = try? doc.title(),
           !title.isEmpty {
            let cleaned = title
                .components(separatedBy: CharacterSet(charactersIn: "|–—-"))
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned ?? title
        }

        return "Sans titre"
    }

    // MARK: - Suppression du bruit HTML

    /// Retire les éléments HTML qui ne font pas partie du contenu.
    /// Équivalent de : document.querySelectorAll("nav, footer, ...").forEach(el => el.remove())
    private func removeNoise(from doc: Document) {
        let noiseSelectors = [
            "nav", "header", "footer", "aside",
            "script", "style", "noscript", "iframe",
            ".sidebar", ".nav", ".menu", ".footer", ".header",
            ".ad", ".ads", ".advertisement", ".social-share",
            ".comments", ".comment", "#comments",
            ".related", ".recommended", ".newsletter",
            "[role=navigation]", "[role=banner]", "[role=contentinfo]"
        ]

        for selector in noiseSelectors {
            // do/catch silencieux acceptable ici : supprimer du bruit n'est pas critique.
            do {
                let elements = try doc.select(selector)
                _ = try elements.remove()
            } catch {
                // Sélecteur invalide ou élément introuvable — on continue
                continue
            }
        }
    }

    // MARK: - Extraction du contenu principal

    /// Essaie de trouver le contenu principal de la page.
    /// Même concept que les algorithmes "readability" (Firefox Reader View).
    private func extractMainContent(from doc: Document) -> String {
        let contentSelectors = [
            "article",
            "[role=main]",
            "main",
            ".post-content",
            ".article-content",
            ".entry-content",        // WordPress classique
            ".content-body",
            "#article-body",
            ".story-body",
            ".post-body",
        ]

        for selector in contentSelectors {
            if let element = try? doc.select(selector).first(),
               let text = try? element.text(),
               text.count > 200 {
                return cleanText(text)
            }
        }

        // Fallback : prendre le <body> entier
        if let bodyText = try? doc.body()?.text(),
           !bodyText.isEmpty {
            return cleanText(bodyText)
        }

        return ""
    }

    // MARK: - Nettoyage du texte

    private func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
