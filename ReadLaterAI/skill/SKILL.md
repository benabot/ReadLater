---
name: readlater-ai
description: Aide au développement de ReadLater AI, une app macOS menu bar native en Swift/SwiftUI. Utiliser ce skill quand l'utilisateur (1) mentionne ReadLater AI, ReadLater, ou le chemin /Users/benoitabot/Sites/ReadLater/ReadlLater, (2) travaille sur du code Swift/SwiftUI pour cette app (modèles SwiftData, vues, services, LLM providers), (3) demande de l'aide sur l'architecture menu bar, NSPopover, SwiftData, SwiftSoup, Keychain, ou l'export vers Bear/iA Writer/Notes, (4) discute de la roadmap ou des étapes du projet (squelette, extraction, LLM, export, UI), (5) mentionne le bundle ID com.benoitabot.ReadLaterAI. Toujours utiliser ce skill pour tout travail lié à cette app, même pour des questions Swift/SwiftUI générales si elles concernent ce projet.
---

# ReadLater AI — App macOS Menu Bar

Assister le développement d'une app macOS menu bar native qui capture des URLs, extrait le contenu d'articles, génère des résumés via LLM (Claude, OpenAI, Ollama), et exporte vers Bear, iA Writer ou Notes.

**Projet :** `/Users/benoitabot/Sites/ReadLater/ReadlLater/`
**Bundle ID :** `com.benoitabot.ReadLaterAI`
**Target :** macOS 14 Sonoma minimum

## Workflow de démarrage

**Toujours commencer par :**
1. Lire `ReadLaterAI/CLAUDE.md` — source de vérité complète du projet
2. Vérifier la structure actuelle avec `ls ReadLaterAI/`
3. Ne jamais supposer l'état du code sans vérifier les fichiers existants

## Stack technique

| Couche | Choix |
|--------|-------|
| UI | SwiftUI (MenuBarExtra + `.window` style) |
| Persistance | SwiftData (@Model, @Query, ModelContainer) |
| Parsing HTML | SwiftSoup (seule dépendance SPM) |
| Réseau | URLSession async/await |
| LLM | Claude API, OpenAI API, Ollama local |
| Export | Bear (URL scheme), iA Writer (URL scheme), Notes (NSSharingService) |
| Sécurité | Keychain pour les clés API |
| Build | XcodeGen (project.yml → .xcodeproj) |

## Architecture des fichiers

```
ReadlLater/
├── project.yml                 # Config XcodeGen
├── ReadLaterAI.xcodeproj       # Généré par XcodeGen
└── ReadLaterAI/
    ├── CLAUDE.md               # Specs complètes du projet
    ├── ReadLaterAIApp.swift     # @main, MenuBarExtra
    ├── Models/
    │   └── Article.swift       # @Model SwiftData
    ├── Views/
    │   ├── ContentView.swift   # Vue popover principale
    │   ├── ArticleRowView.swift
    │   ├── ArticleDetailView.swift
    │   ├── ExportMenuView.swift
    │   └── PreferencesView.swift
    ├── Services/
    │   ├── ArticleExtractor.swift
    │   ├── ClipboardMonitor.swift
    │   ├── KeychainService.swift
    │   └── ExportService.swift
    ├── LLM/
    │   ├── LLMProvider.swift
    │   ├── ClaudeProvider.swift
    │   ├── OpenAIProvider.swift
    │   └── OllamaProvider.swift
    ├── Utilities/
    │   └── GlobalShortcut.swift
    └── Resources/
        ├── ReadLaterAI.entitlements
        └── Assets.xcassets/
```

## Contraintes absolues

- **Sandbox activé** (App Store compatible)
- **LSUIElement = YES** → menu bar only, pas d'icône Dock
- **Clés API → Keychain uniquement**, jamais UserDefaults
- **Zéro dépendance tierce sauf SwiftSoup** (SPM)
- **Swift moderne** : async/await, actors, @Observable (PAS ObservableObject)
- **SwiftData** : @Model, @Query (PAS CoreData)
- **Pas de Combine** sauf cas exceptionnel
- **Pas d'UIKit** — SwiftUI natif + AppKit minimal (NSPopover, NSStatusBar)

## Patterns de code obligatoires

### Gestion d'erreur
```swift
enum ArticleError: LocalizedError {
    case invalidURL
    case networkTimeout
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: "L'URL fournie n'est pas valide"
        case .networkTimeout: "La requête a expiré"
        case .parsingFailed(let detail): "Erreur de parsing : \(detail)"
        }
    }
}
```

### Modèle SwiftData
```swift
@Model
final class Article {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var summaryData: Data?  // Summary encodé en JSON
    var dateAdded: Date
    var isRead: Bool
}
```

### Protocol LLM
```swift
protocol LLMProvider: Sendable {
    var name: String { get }
    func summarize(text: String, language: String) async throws -> Summary
}
```

## Roadmap (5 étapes)

| Étape | Contenu | Statut |
|-------|---------|--------|
| 1 | Squelette menu bar, popover, SwiftData | ✅ Fait |
| 2 | Capture URL, extraction HTML (SwiftSoup), clipboard | À faire |
| 3 | Couche LLM multi-provider, Keychain | À faire |
| 4 | Export Bear/iA Writer/Notes/Clipboard | À faire |
| 5 | Préférences, ArticleRowView, raccourci ⌥⌘R | À faire |

## Commandes utiles

```bash
# Régénérer le projet Xcode après modif de project.yml ou ajout de fichiers
cd /Users/benoitabot/Sites/ReadLater/ReadlLater && xcodegen generate

# Build
xcodebuild -project ReadLaterAI.xcodeproj -scheme ReadLaterAI -configuration Debug build

# Lancer l'app
open ~/Library/Developer/Xcode/DerivedData/ReadLaterAI-*/Build/Products/Debug/ReadLater\ AI.app
```

## Contexte développeur

Le développeur est un **dev web (JS, PHP, Vue.js, WordPress) qui apprend Swift**. En conséquence :
- Expliquer les patterns Swift avec des analogies web (ex: `@Observable` ≈ `reactive()` en Vue 3)
- Fournir du code complet et fonctionnel, jamais de pseudo-code
- Signaler les pièges courants pour un dev web (optionals, value types, ARC)

## Ce qu'il ne faut PAS faire

- ❌ Stocker des clés API dans UserDefaults ou en dur
- ❌ Utiliser `try?` sans logger l'erreur
- ❌ Utiliser ObservableObject/@Published → @Observable
- ❌ Utiliser Combine pour du réseau → async/await
- ❌ Créer une fenêtre principale (menu bar only)
- ❌ Oublier @MainActor sur les vues
- ❌ Modifier le .xcodeproj à la main → modifier project.yml + xcodegen
