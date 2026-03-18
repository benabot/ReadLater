import Foundation

// MARK: - LLMProvider Protocol
// Protocol qui définit l'interface commune pour tous les providers LLM.
//
// En Swift, un protocol est l'équivalent d'une interface TypeScript :
// il déclare les méthodes/propriétés que tout type conforme doit implémenter.
//
// `Sendable` signifie que le type peut être envoyé entre threads en toute
// sécurité — nécessaire car les providers sont utilisés depuis un actor.

protocol LLMProvider: Sendable {
    /// Nom du provider affiché dans l'UI (ex: "Claude", "OpenAI")
    var name: String { get }

    /// Nom du modèle utilisé (ex: "claude-sonnet-4-20250514")
    var modelName: String { get }

    /// Résume un texte en utilisant l'API du provider.
    /// Le résumé est généré dans la même langue que l'article source.
    func summarize(text: String) async throws -> Summary
}

// MARK: - LLMError

enum LLMError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse(String)
    case apiError(statusCode: Int, message: String)
    case networkError(String)
    case jsonDecodingFailed(String)
    case textTooShort

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            String(localized: "Missing API key for \(provider). Configure it in Preferences.")
        case .invalidResponse(let detail):
            String(localized: "Invalid LLM response: \(detail)")
        case .apiError(let statusCode, let message):
            String(localized: "API error (\(statusCode)): \(message)")
        case .networkError(let detail):
            String(localized: "LLM network error: \(detail)")
        case .jsonDecodingFailed(let detail):
            String(localized: "Unable to decode JSON summary: \(detail)")
        case .textTooShort:
            String(localized: "Text is too short to summarize (minimum 100 characters)")
        }
    }
}

// MARK: - Prompt système

/// Le prompt système envoyé à tous les providers.
/// On le centralise ici pour garantir la cohérence entre Claude, OpenAI et Ollama.
enum LLMPrompt {

    static func system() -> String {
        """
        You are a reading assistant. Summarize the following article.
        Write the summary in the SAME language as the article.

        Respond ONLY with valid JSON (no backticks, no markdown, no comments) using this exact structure:
        {
          "tldr": "2-3 sentence concise summary",
          "keyPoints": ["point 1", "point 2", "point 3"],
          "readingTime": 5,
          "tags": ["tag1", "tag2", "tag3"]
        }

        Rules:
        - tldr: 2-3 sentences maximum, factual and concise
        - keyPoints: 3-5 key points, each one sentence
        - readingTime: estimated reading time in minutes (integer)
        - tags: 3-5 relevant lowercase tags
        """
    }

    /// Tronque le texte si trop long (les APIs ont des limites de tokens).
    /// On garde les premiers ~12000 caractères (≈ 3000 tokens).
    static func truncateIfNeeded(_ text: String, maxChars: Int = 12000) -> String {
        if text.count <= maxChars { return text }
        let truncated = String(text.prefix(maxChars))
        return truncated + "\n\n[Texte tronqué pour respecter la limite de tokens]"
    }
}

// MARK: - JSON Parsing Helper

/// Parse un JSON Summary depuis la réponse textuelle du LLM.
/// Les LLM retournent parfois du JSON enveloppé dans des backticks markdown,
/// donc on nettoie avant de décoder.
enum SummaryParser {
    static func parse(from text: String) throws -> Summary {
        // Nettoyer : retirer les backticks markdown (```json ... ```)
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Retirer les blocs ```json ou ```
        if cleaned.hasPrefix("```") {
            // Trouver la fin du premier ``` (qui peut être ```json)
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[firstNewline...])
            }
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw LLMError.jsonDecodingFailed("Impossible de convertir en Data")
        }

        do {
            let summary = try JSONDecoder().decode(Summary.self, from: data)
            return summary
        } catch {
            throw LLMError.jsonDecodingFailed("JSON invalide : \(error.localizedDescription). Réponse brute : \(String(cleaned.prefix(200)))")
        }
    }
}
