# ReadLater AI

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" alt="Swift 6">
  <img src="https://img.shields.io/badge/SwiftUI-✓-blue" alt="SwiftUI">
  <img src="https://img.shields.io/badge/SwiftData-✓-green" alt="SwiftData">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT License">
</p>

**App macOS menu bar qui capture des URLs, extrait le contenu d'articles, génère des résumés IA et exporte vers vos apps de notes.**

ReadLater AI vit dans votre barre de menus — pas d'icône dans le Dock, pas de fenêtre encombrante. Collez une URL, l'app extrait le contenu, le résume avec l'IA de votre choix et l'exporte en Markdown vers Bear, Obsidian, iA Writer ou 5 autres apps.

---

## Fonctionnalités

### Capture d'articles
- **Ajout par URL** — collez une URL, le contenu est extrait automatiquement (titre, texte, nombre de mots)
- **Détection clipboard** — copiez une URL n'importe où, une bannière propose de l'ajouter
- **Import Safari** — importez votre Reading List Safari en un clic

### Résumé IA
- **Multi-provider** — Claude (Anthropic), OpenAI ou Ollama (local, gratuit)
- **Résumé structuré** — TL;DR, points clés, temps de lecture estimé, tags auto-générés
- **Multilingue** — résumés en français, anglais, espagnol, allemand, italien, portugais

### Export
- **8 apps supportées** — Bear, iA Writer, Obsidian, Craft, Ulysses, Evernote, Apple Notes, Clipboard
- **Format Markdown** — titre, source, résumé, points clés, tags
- **Clic droit** — menu contextuel sur chaque article pour exporter

### Interface
- **Menu bar only** — vit dans la barre de menus, pas d'icône Dock
- **Onboarding** — présentation guidée au premier lancement
- **Mode d'emploi** — aide intégrée accessible à tout moment
- **Préférences** — provider IA, clés API (Keychain), langue, raccourci clavier

---

## Installation

### Prérequis

- macOS 14 Sonoma ou supérieur
- Xcode 16+ (pour compiler)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optionnel, pour régénérer le projet)

### Compilation

```bash
git clone https://github.com/benoitabot/ReadLaterAI.git
cd ReadLaterAI

# Ouvrir dans Xcode
open ReadLaterAI.xcodeproj

# Ou compiler depuis le terminal
xcodebuild -project ReadLaterAI.xcodeproj -scheme ReadLaterAI -configuration Debug build
```

### Avec XcodeGen (optionnel)

Si vous modifiez la structure du projet :

```bash
brew install xcodegen
xcodegen generate
```

---

## Configuration des providers IA

### Ollama (gratuit, local)

```bash
brew install ollama
ollama pull llama3.2
ollama serve
```

Aucune clé API nécessaire. Les données restent sur votre machine.

### Claude (Anthropic)

1. Créez un compte sur [console.anthropic.com](https://console.anthropic.com)
2. Générez une clé API
3. Dans l'app : Préférences → IA → collez votre clé Claude

### OpenAI

1. Créez un compte sur [platform.openai.com](https://platform.openai.com)
2. Générez une clé API
3. Dans l'app : Préférences → IA → collez votre clé OpenAI

> Les clés API sont stockées dans le Keychain macOS (chiffré), jamais en clair.

---

## Architecture

```
ReadLaterAI/
├── ReadLaterAIApp.swift          # Point d'entrée, MenuBarExtra
├── Models/
│   └── Article.swift             # @Model SwiftData + Summary
├── Views/
│   ├── ContentView.swift         # Vue principale, navigation inline
│   ├── SafariImportView.swift    # Import Safari Reading List
│   ├── PreferencesView.swift     # Préférences (IA, Général)
│   ├── OnboardingView.swift      # Bienvenue au premier lancement
│   ├── HelpView.swift            # Mode d'emploi
│   └── ExportMenuView.swift      # Menu contextuel d'export
├── Services/
│   ├── ArticleExtractor.swift    # Fetch HTML + SwiftSoup
│   ├── ClipboardMonitor.swift    # Détection URLs clipboard
│   ├── SafariImporter.swift      # Lecture Bookmarks.plist
│   ├── KeychainService.swift     # CRUD Keychain natif
│   └── ExportService.swift       # Export vers 8 apps
├── LLM/
│   ├── LLMProvider.swift         # Protocol + prompt + parser
│   ├── ClaudeProvider.swift      # Anthropic API
│   ├── OpenAIProvider.swift      # OpenAI API
│   └── OllamaProvider.swift      # Ollama local
└── Utilities/
    └── GlobalShortcut.swift      # Raccourci clavier personnalisable
```

### Stack technique

| Couche | Technologie |
|--------|-------------|
| UI | SwiftUI (MenuBarExtra) |
| Persistance | SwiftData (SQLite) |
| Parsing HTML | [SwiftSoup](https://github.com/scinfu/SwiftSoup) |
| Réseau | URLSession async/await |
| Sécurité | Keychain natif |
| Export | URL schemes + NSSharingService |

### Choix techniques

- **Swift 6 strict concurrency** — actors, @Sendable, @MainActor
- **@Observable** (pas ObservableObject) — réactivité moderne
- **Zéro dépendance tierce** sauf SwiftSoup pour le parsing HTML
- **Pas de Combine** — tout en async/await
- **Sandbox activée** — compatible App Store

---

## Utilisation

### Ajouter un article
1. Cliquez sur l'icône 📄🔍 dans la barre de menus
2. Collez une URL dans le champ en haut → le contenu est extrait automatiquement
3. Ou copiez une URL n'importe où → une bannière bleue propose de l'ajouter

### Résumer avec l'IA
1. Cliquez sur l'icône ✨ à droite d'un article
2. Le résumé apparaît : TL;DR, points clés, temps de lecture, tags
3. Cliquez sur l'article pour afficher/masquer le résumé

### Exporter
1. Faites un **clic droit** sur un article
2. Choisissez l'app de destination (Bear, Obsidian, iA Writer, etc.)
3. Le contenu est exporté en Markdown formaté

### Import Safari
1. Cliquez sur l'icône Safari dans le footer
2. Sélectionnez `~/Library/Safari/Bookmarks.plist`
3. Choisissez les articles à importer → le contenu est extrait en batch

---

## Roadmap

- [x] Squelette menu bar + SwiftData
- [x] Capture d'URL + extraction HTML
- [x] LLM multi-provider (Claude, OpenAI, Ollama)
- [x] Export 8 apps (Bear, iA Writer, Obsidian, Craft, Ulysses, Evernote, Notes, Clipboard)
- [x] Préférences (provider, clés API, langue, raccourci)
- [x] Onboarding + mode d'emploi
- [ ] Raccourci global fonctionnel (toggle popover via NSStatusBar)
- [ ] Recherche et filtres dans la liste d'articles
- [ ] Icône app custom
- [ ] Distribution via Gumroad / Mac App Store

---

## Licence

MIT — voir [LICENSE](LICENSE)

---

Créé par [beabot.fr](https://beabot.fr)
