import Foundation
import Security

// MARK: - KeychainService
// Service CRUD pour stocker/lire/supprimer des clés API dans le Keychain macOS.
//
// Le Keychain est le coffre-fort natif d'Apple pour stocker des secrets
// (mots de passe, tokens, clés API). C'est chiffré par le système et protégé
// par le mot de passe utilisateur ou Touch ID.
//
// Pourquoi pas UserDefaults ? UserDefaults stocke en clair dans un .plist
// lisible par n'importe quel processus. Le Keychain est chiffré et isolé.
// C'est la différence entre stocker un mot de passe dans localStorage (mauvais)
// vs dans un cookie httpOnly secure (mieux).
//
// L'API Keychain d'Apple (Security framework) est une API C très verbeuse.
// On l'encapsule ici dans un service Swift propre.

enum KeychainService {

    // MARK: - Identifiants de clés

    /// Le "service" est un identifiant unique pour regrouper nos entrées Keychain.
    /// C'est comme un namespace. On utilise le bundle ID de l'app.
    private static let service = "fr.beabot.ReadLaterAI"

    /// Les clés sous lesquelles on stocke chaque provider.
    /// Ce sont les "account" dans la terminologie Keychain.
    enum Key: String, CaseIterable, Sendable {
        case claude = "api-key-claude"
        case openAI = "api-key-openai"

        var displayName: String {
            switch self {
            case .claude: "Claude (Anthropic)"
            case .openAI: "OpenAI"
            }
        }
    }

    // MARK: - Erreurs

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
        case dataConversionFailed

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                String(localized: "Unable to save to Keychain (error \(status))")
            case .readFailed(let status):
                String(localized: "Unable to read Keychain (error \(status))")
            case .deleteFailed(let status):
                String(localized: "Unable to delete from Keychain (error \(status))")
            case .dataConversionFailed:
                String(localized: "Unable to convert Keychain data")
            }
        }
    }

    // MARK: - Save

    /// Stocke une clé API dans le Keychain.
    ///
    /// L'API Keychain fonctionne avec des dictionnaires `[String: Any]` appelés "queries".
    /// Chaque entrée est identifiée par le triplet (class, service, account).
    /// C'est comme une table SQL avec une clé composite.
    ///
    /// - Parameters:
    ///   - apiKey: La clé API à stocker (ex: "sk-ant-api03-...")
    ///   - key: L'identifiant de la clé (claude ou openAI)
    static func save(apiKey: String, for key: Key) throws {
        // Convertir la string en Data (octets).
        // Le Keychain stocke des Data, pas des String.
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        // Supprimer l'entrée existante si elle existe (update = delete + add).
        // SecItemDelete retourne errSecItemNotFound si l'entrée n'existe pas,
        // ce qu'on ignore (ce n'est pas une erreur).
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Ajouter la nouvelle entrée.
        // kSecClass: type d'entrée (mot de passe générique)
        // kSecAttrService: identifiant de notre app
        // kSecAttrAccount: identifiant de cette clé spécifique
        // kSecValueData: la valeur à stocker (chiffrée par le Keychain)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Read

    /// Lit une clé API depuis le Keychain.
    ///
    /// Retourne nil si la clé n'existe pas (pas d'erreur dans ce cas).
    /// C'est comme un GET qui retourne 404 — c'est un cas normal, pas une erreur.
    static func read(for key: Key) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            // kSecReturnData: demande au Keychain de retourner la valeur
            kSecReturnData as String: true,
            // kSecMatchLimit: on veut un seul résultat
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // SecItemCopyMatching est la fonction de lecture du Keychain.
        // Elle prend un pointeur `result` qu'elle remplit avec les données.
        // C'est un pattern C classique : la fonction écrit dans un pointeur de sortie.
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil  // Pas de clé stockée — c'est normal
        }

        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }

        // Caster le résultat en Data puis en String.
        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        return apiKey
    }

    // MARK: - Delete

    /// Supprime une clé API du Keychain.
    static func delete(for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound = la clé n'existait pas → pas une erreur
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Has Key

    /// Vérifie si une clé API existe dans le Keychain (sans la lire).
    static func hasKey(for key: Key) -> Bool {
        (try? read(for: key)) != nil
    }
}
