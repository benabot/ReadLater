import Foundation

// MARK: - ClaudeProvider
// Provider LLM pour l'API Anthropic (Claude).
//
// L'API Claude utilise un format légèrement différent d'OpenAI :
// - Header `x-api-key` au lieu de `Authorization: Bearer`
// - Header `anthropic-version` obligatoire
// - Structure de requête/réponse spécifique
//
// C'est un struct (value type) conforme à LLMProvider + Sendable,
// ce qui permet de l'utiliser en toute sécurité entre threads.

struct ClaudeProvider: LLMProvider {

    let name = "Claude"
    let modelName: String

    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    init(model: String = "claude-sonnet-4-20250514") {
        self.modelName = model
    }

    // MARK: - Summarize

    func summarize(text: String) async throws -> Summary {
        // Vérifier la clé API dans le Keychain
        guard let apiKey = try KeychainService.read(for: .claude) else {
            throw LLMError.missingAPIKey("Claude")
        }

        guard text.count >= 100 else {
            throw LLMError.textTooShort
        }

        let truncatedText = LLMPrompt.truncateIfNeeded(text)

        // Construire le body de la requête.
        // L'API Claude attend :
        // {
        //   "model": "claude-sonnet-4-20250514",
        //   "max_tokens": 1024,
        //   "system": "prompt système",
        //   "messages": [{"role": "user", "content": "texte"}]
        // }
        let requestBody: [String: Any] = [
            "model": modelName,
            "max_tokens": 1024,
            "system": LLMPrompt.system(),
            "messages": [
                ["role": "user", "content": truncatedText]
            ]
        ]

        // Construire la requête HTTP
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Envoyer la requête
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("Réponse HTTP invalide")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "?"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parser la réponse Claude.
        // La réponse a cette structure :
        // {
        //   "content": [{"type": "text", "text": "le JSON résumé"}],
        //   "stop_reason": "end_turn"
        // }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let textContent = firstBlock["text"] as? String else {
            throw LLMError.invalidResponse("Structure de réponse Claude inattendue")
        }

        return try SummaryParser.parse(from: textContent)
    }
}
