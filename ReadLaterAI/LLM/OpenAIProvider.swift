import Foundation

// MARK: - OpenAIProvider
// Provider LLM pour l'API OpenAI (GPT-4o-mini, GPT-4o, etc.)
//
// L'API OpenAI est le standard de facto. La plupart des APIs LLM
// (Mistral, Groq, Together, etc.) utilisent le même format "OpenAI-compatible".

struct OpenAIProvider: LLMProvider {

    let name = "OpenAI"
    let modelName: String

    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(model: String = "gpt-4o-mini") {
        self.modelName = model
    }

    func summarize(text: String, language: String) async throws -> Summary {
        guard let apiKey = try KeychainService.read(for: .openAI) else {
            throw LLMError.missingAPIKey("OpenAI")
        }

        guard text.count >= 100 else {
            throw LLMError.textTooShort
        }

        let truncatedText = LLMPrompt.truncateIfNeeded(text)

        // Format OpenAI Chat Completions :
        // {
        //   "model": "gpt-4o-mini",
        //   "messages": [
        //     {"role": "system", "content": "prompt système"},
        //     {"role": "user", "content": "texte"}
        //   ],
        //   "temperature": 0.3
        // }
        let requestBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": LLMPrompt.system(language: language)],
                ["role": "user", "content": truncatedText]
            ],
            "temperature": 0.3,
            "max_tokens": 1024
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // OpenAI utilise le header Authorization avec Bearer token
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("Réponse HTTP invalide")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "?"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parser la réponse OpenAI :
        // {
        //   "choices": [{"message": {"content": "le JSON résumé"}}]
        // }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let textContent = message["content"] as? String else {
            throw LLMError.invalidResponse("Structure de réponse OpenAI inattendue")
        }

        return try SummaryParser.parse(from: textContent)
    }
}
