# CLAUDE.md — ReadLater AI

## Identité du projet

ReadLater AI est une app macOS **menu bar only** qui capture des URLs, extrait le contenu d'articles web, génère des résumés via LLM (Claude, OpenAI, Ollama), et exporte vers Bear, iA Writer ou Notes.

**Bundle ID** : `fr.beabot.ReadLaterAI`
**Target** : macOS 14 Sonoma minimum
**Xcode project** : `/Users/benoitabot/Sites/ReadLater/ReadlLater/`
**Doc & specs** : `/Users/benoitabot/Sites/ReadLater/doc/`

---

## Stack technique

| Couche | Choix |
|--------|-------|
| UI | SwiftUI (NSPopover depuis menu bar) |
| Persistance | SwiftData (macOS 14+) |
| Parsing HTML | SwiftSoup (seule dépendance SPM) |
| Réseau | URLSession async/await |
| LLM | Claude API, OpenAI API, Ollama (local) |
| Export | Bear (URL scheme), iA Writer (URL scheme), Notes (NSSharingService) |
| Sécurité | Keychain pour les clés API |

---

## Architecture des fichiers

```
ReadlLater/
├── ReadLaterAIApp.swift        # @main, MenuBarExtra, NSPopover setup
├── ContentView.swift           # Vue principale du popover
├── Models/
│   └── Article.swift           # @Model SwiftData (id, url, title, summary, date, isRead)
├── Services/
│   ├── ArticleExtractor.swift  # Fetch HTML + extraction SwiftSoup
│   ├── ClipboardMonitor.swift  # Surveillance NSPasteboard
│   ├── SafariImporter.swift    # Lecture Safari Reading List (.plist)
│   ├── KeychainService.swift   # CRUD clés API dans Keychain
│   └── ExportService.swift     # Export Bear/iA Writer/Notes/Clipboard
├── LLM/
│   ├── LLMProvider.swift       # Protocol + struct Summary
│   ├── ClaudeProvider.swift    # Anthropic API
│   ├── OpenAIProvider.swift    # OpenAI API
│   └── OllamaProvider.swift    # Ollama local
├── Views/
│   ├── ArticleRowView.swift    # Ligne dans la liste
│   ├── ArticleDetailView.swift # Vue résumé expandée
│   ├── ExportMenuView.swift    # Menu contextuel d'export
│   └── PreferencesView.swift   # Settings (LLM, Export, Capture, Général)
└── Utilities/
    └── GlobalShortcut.swift    # ⌥⌘R pour toggle popover
```

---

## Contraintes absolues

### Sandbox & sécurité
- **App Sandbox activé** (compatibilité App Store)
- **Entitlement** : `com.apple.security.network.client` (requêtes réseau)
- **LSUIElement = YES** dans Info.plist → pas d'icône Dock, menu bar only
- **Clés API → Keychain uniquement**, jamais UserDefaults, jamais en dur dans le code

### Dépendances
- **Zéro dépendance tierce sauf SwiftSoup** (via SPM)
- URL du package : `https://github.com/scinfu/SwiftSoup`
- Pas de Alamofire, pas de KeychainAccess → tout en natif

### Compatibilité
- macOS 14 Sonoma minimum (`@available(macOS 14.0, *)`)
- Pas d'API deprecées, pas de AppKit sauf NSPopover et NSStatusBar (nécessaires pour le menu bar)

---

## Style de code

### Patterns obligatoires
- **Swift moderne** : async/await, actors, `@Observable` (pas ObservableObject)
- **SwiftData** : `@Model`, `@Query`, `ModelContainer`, `ModelContext`
- **Gestion d'erreur** : enums conformes à `Error` + `LocalizedError`, pas de `try?` silencieux
- **Pas de Combine** sauf cas exceptionnel justifié
- **Pas d'UIKit** — tout en SwiftUI natif + AppKit minimal (NSPopover, NSStatusBar)

### Conventions de nommage
- Types : `PascalCase` (ex: `ArticleExtractor`, `LLMProvider`)
- Propriétés/méthodes : `camelCase` (ex: `fetchArticle`, `isRead`)
- Enums d'erreur : `NomDuModuleError` (ex: `ArticleError`, `KeychainError`, `LLMError`)
- Fichiers : un type principal par fichier, nom = nom du type

### Exemple de pattern erreur attendu
```swift
enum ArticleError: LocalizedError {
    case invalidURL
    case networkTimeout
    case emptyContent
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: "L'URL fournie n'est pas valide"
        case .networkTimeout: "La requête a expiré (timeout 10s)"
        case .emptyContent: "Aucun contenu exploitable trouvé"
        case .parsingFailed(let detail): "Erreur de parsing : \(detail)"
        }
    }
}
```

---

## Modèle de données (SwiftData)

```swift
@Model
final class Article {
    var id: UUID
    var url: String
    var title: String
    var summary: Summary?  // Encodable/Decodable struct
    var dateAdded: Date
    var isRead: Bool
    var wordCount: Int
    var extractedText: String?
    
    init(url: String, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.dateAdded = Date()
        self.isRead = false
        self.wordCount = 0
    }
}
```

---

## Protocol LLM

```swift
protocol LLMProvider: Sendable {
    var name: String { get }
    func summarize(text: String, language: String) async throws -> Summary
}

struct Summary: Codable {
    let tldr: String          // 2-3 phrases
    let keyPoints: [String]   // 3-5 bullet points
    let readingTime: Int      // minutes estimées
    let tags: [String]        // 3-5 tags auto-générés
}
```

### Prompt système LLM
```
Tu es un assistant de lecture. Résume l'article suivant en [language].
Réponds UNIQUEMENT en JSON valide avec les clés : tldr, keyPoints, readingTime, tags.
Sois concis, factuel, et conserve les nuances importantes.
```

### Endpoints
| Provider | URL | Modèle par défaut |
|----------|-----|-------------------|
| Claude | `https://api.anthropic.com/v1/messages` | claude-sonnet-4-20250514 |
| OpenAI | `https://api.openai.com/v1/chat/completions` | gpt-4o-mini |
| Ollama | `http://localhost:11434/api/generate` | llama3.2 |

---

## URL Schemes export

```
# Bear
bear://x-callback-url/create?title={title}&text={markdown}&tags=readlater

# iA Writer
ia-writer://new?text={markdown}
```

Pour Notes : `NSSharingServicePicker` avec le contenu Markdown.

---

## Roadmap (5 étapes)

1. **Squelette menu bar** ✅ — App SwiftUI menu bar, popover, modèle SwiftData
2. **Capture d'URL & extraction** ✅ — Fetch HTML, SwiftSoup, clipboard, Safari Reading List
3. **Couche LLM multi-provider** ✅ — Protocol, Claude/OpenAI/Ollama, Keychain
4. **Export multi-cible** ✅ — Bear, iA Writer, Obsidian, Craft, Ulysses, Evernote, Notes, Clipboard
5. **Préférences & UI finale** ✅ — Settings, provider selector, Keychain UI, raccourci ⌥⌘R

---

## Contexte développeur

Le développeur principal est un **dev web (JS, PHP, Vue.js, WordPress) qui apprend Swift**. En conséquence :
- **Explique les patterns Swift** quand tu les introduis (actors, @Observable, property wrappers, etc.)
- **Fournis du code complet et fonctionnel**, pas de pseudo-code ni de "TODO: implémenter ici"
- **Fais des analogies avec le web** quand c'est pertinent (ex: `@Observable` ≈ `reactive()` en Vue 3)
- **Signale les pièges courants** pour un dev web venant vers Swift (optionals, value types vs reference types, ARC)

---

## Commandes utiles

```bash
# Build depuis le terminal
xcodebuild -project ReadlLater.xcodeproj -scheme ReadLaterAI -configuration Debug build

# Lancer l'app compilée
open ./Build/Products/Debug/ReadLaterAI.app

# Vérifier les entitlements d'un .app
codesign -d --entitlements - ReadLaterAI.app

# Tester Ollama local
curl http://localhost:11434/api/generate -d '{"model":"llama3.2","prompt":"Hello"}'

# Ouvrir Bear via URL scheme (test)
open "bear://x-callback-url/create?title=Test&text=Hello"

# Ouvrir iA Writer via URL scheme (test)
open "ia-writer://new?text=Hello%20World"
```

---

## Ce qu'il ne faut PAS faire

- ❌ Stocker des clés API dans UserDefaults ou en dur
- ❌ Utiliser `try?` sans logger l'erreur
- ❌ Ajouter des dépendances SPM non approuvées (SwiftSoup uniquement)
- ❌ Utiliser ObservableObject/@Published (→ utiliser @Observable)
- ❌ Utiliser Combine pour du réseau (→ async/await)
- ❌ Créer une fenêtre principale (l'app est menu bar only)
- ❌ Oublier le `@MainActor` sur les vues et les updates UI
- ❌ Ignorer la Sandbox — tester avec sandbox activée systématiquement

---

## Monétisation prévue

| Tier | Détail |
|------|--------|
| Gratuit | 10 résumés/mois, Ollama uniquement |
| Pro (15€/an) | Illimité, Claude + OpenAI, tous exports, historique |

Distribution : GitHub (open source) → Gumroad (Pro) → Mac App Store (phase 2).
