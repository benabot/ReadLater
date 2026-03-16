import Foundation

// MARK: - OllamaProvider
// Provider LLM pour Ollama (modèles locaux).
//
// Ollama est un serveur local qui fait tourner des LLM sur ta machine.
// Pas besoin de clé API — tout tourne en local sur http://localhost:11434.
// C'est le provider gratuit par défaut de ReadLater AI.
//
// Pour l'installer : `brew install ollama && ollama pull llama3.2`
// Pour le lancer : `ollama serve`

struct OllamaProvider: LLMProvider {

    let name = "Ollama"
    let modelName: String

    private let baseURL: String

    init(model: String = "llama3.2", baseURL: String = "http://localhost:11434") {
        self.modelName = model
        self.baseURL = baseURL
    }

    func summarize(text: String, language: String) async throws -> Summary {
        guard text.count >= 100 else {
            throw LLMError.textTooShort
        }

        // Vérifier que Ollama tourne en essayant de le contacter.
        // On tente d'abord un GET sur /api/tags pour voir s'il répond.
        let isRunning = await checkOllamaRunning()
        guard isRunning else {
            throw LLMError.networkError("Ollama ne répond pas sur \(baseURL). Vérifiez qu'il est lancé avec `ollama serve`.")
        }

        let truncatedText = LLMPrompt.truncateIfNeeded(text, maxChars: 8000)

        // API Ollama /api/generate :
        // {
        //   "model": "llama3.2",
        //   "prompt": "texte",
        //   "system": "prompt système",
        //   "stream": false
        // }
        // stream: false retourne la réponse complète en une fois
        // (par défaut Ollama stream token par token, comme un EventSource en JS).
        guard let apiURL = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.networkError("URL Ollama invalide")
        }

        let requestBody: [String: Any] = [
            "model": modelName,
            "system": LLMPrompt.system(language: language),
            "prompt": truncatedText,
            "stream": false,
            "options": [
                "temperature": 0.3
            ]
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Timeout plus long pour Ollama (les modèles locaux sont plus lents)
        request.timeoutInterval = 120

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("Réponse HTTP invalide d'Ollama")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "?"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Réponse Ollama :
        // { "response": "le JSON résumé", "done": true, ... }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let textContent = json["response"] as? String else {
            throw LLMError.invalidResponse("Structure de réponse Ollama inattendue")
        }

        return try SummaryParser.parse(from: textContent)
    }

    // MARK: - Health Check

    /// Vérifie si Ollama répond sur localhost.
    private func checkOllamaRunning() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
