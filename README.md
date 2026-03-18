# ReadLater AI

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" alt="Swift 6">
  <img src="https://img.shields.io/badge/SwiftUI-✓-blue" alt="SwiftUI">
  <img src="https://img.shields.io/badge/SwiftData-✓-green" alt="SwiftData">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT License">
</p>

**A native macOS menu bar app that captures URLs, extracts article content, generates AI summaries and exports to your note-taking apps.**

ReadLater AI lives in your menu bar — no Dock icon, no window clutter. Paste a URL, the app extracts the content, summarizes it with the AI of your choice, and exports formatted Markdown to Bear, Obsidian, iA Writer and 5 more apps.

---

## Features

### Article Capture
- **URL input** — paste a URL, content is extracted automatically (title, text, word count)
- **Clipboard detection** — copy a URL anywhere, a banner offers to add it
- **Safari import** — import your Safari Reading List in one click

### AI Summary
- **Multi-provider** — Claude (Anthropic), OpenAI, or Ollama (local, free, private)
- **Structured summary** — TL;DR, key points, estimated reading time, auto-generated tags
- **Multilingual** — summaries in French, English, Spanish, German, Italian, Portuguese
- **Notification** — get notified when a summary is ready

### Export
- **8 supported apps** — Bear, iA Writer, Obsidian, Craft, Ulysses, Evernote, Apple Notes, Clipboard
- **Markdown format** — title, source, summary, key points, tags
- **Export button** — visible share icon on summarized articles + right-click context menu

### Interface
- **Menu bar only** — lives in the menu bar, no Dock icon (LSUIElement)
- **Global shortcut** — ⌥⌘R (customizable) to toggle the popover from any app
- **Liquid glass UI** — translucent materials, gradient borders, glass pills
- **Search & filters** — search by title/URL/tags/summary, filter by All/Unread/Summarized/Failed
- **Delete articles** — via right-click context menu or export menu
- **Onboarding** — guided welcome on first launch
- **Help** — built-in user guide
- **i18n** — English (default) + French, auto-detected from OS language

---

## Installation

### Requirements

- macOS 14 Sonoma or later
- Xcode 16+ (to build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to regenerate the project)

### Build

```bash
git clone https://github.com/benabot/ReadLater.git
cd ReadLater/ReadlLater

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project ReadLaterAI.xcodeproj -scheme ReadLaterAI -configuration Debug build

# Run
open "$(find ~/Library/Developer/Xcode/DerivedData/ReadLaterAI-*/Build/Products/Debug -name 'ReadLater AI.app' -maxdepth 1)"
```

---

## AI Provider Setup

### Ollama (free, local, private)

```bash
brew install ollama
ollama pull llama3.2
ollama serve
```

No API key needed. Your data stays on your machine.

### Claude (Anthropic)

1. Create an account at [console.anthropic.com](https://console.anthropic.com)
2. Generate an API key
3. In the app: Preferences → AI → paste your Claude key

### OpenAI

1. Create an account at [platform.openai.com](https://platform.openai.com)
2. Generate an API key
3. In the app: Preferences → AI → paste your OpenAI key

> API keys are stored in the macOS Keychain (encrypted), never in plain text.

---

## Architecture

```
ReadLaterAI/
├── ReadLaterAIApp.swift          # @main + AppDelegate (NSStatusBar + NSPopover)
├── Models/
│   └── Article.swift             # @Model SwiftData + Summary Codable
├── Views/
│   ├── ContentView.swift         # Main view, search, filters, article rows
│   ├── SafariImportView.swift    # Safari Reading List import
│   ├── PreferencesView.swift     # Tabbed prefs (AI / General)
│   ├── OnboardingView.swift      # 4-page welcome
│   ├── HelpView.swift            # User guide
│   └── ExportMenuView.swift      # Context menu + export button
├── Services/
│   ├── ArticleExtractor.swift    # HTML fetch + SwiftSoup parsing (actor)
│   ├── ClipboardMonitor.swift    # NSPasteboard polling (@Observable)
│   ├── SafariImporter.swift      # Bookmarks.plist reader (actor)
│   ├── KeychainService.swift     # Native Keychain CRUD (enum)
│   └── ExportService.swift       # 8 export targets
├── LLM/
│   ├── LLMProvider.swift         # Protocol + prompt + JSON parser
│   ├── ClaudeProvider.swift      # Anthropic API
│   ├── OpenAIProvider.swift      # OpenAI API
│   └── OllamaProvider.swift      # Ollama local
├── Utilities/
│   ├── GlobalShortcut.swift      # Predefined shortcut picker + ShortcutKey
│   └── GlassStyle.swift          # Liquid glass design system
└── Resources/
    ├── Info.plist                 # Anti-termination keys
    ├── ReadLaterAI.entitlements   # Sandbox + network
    ├── Assets.xcassets/           # App icon (7 PNG sizes)
    ├── icon.svg                   # Source SVG
    └── fr.lproj/Localizable.strings  # 160+ French translations
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (NSPopover) |
| Persistence | SwiftData (SQLite) |
| HTML Parsing | [SwiftSoup](https://github.com/scinfu/SwiftSoup) |
| Networking | URLSession async/await |
| Security | Native Keychain |
| Export | URL schemes + NSSharingService |
| Notifications | UNUserNotificationCenter |

### Technical Choices

- **Swift 6 strict concurrency** — actors, @Sendable, @MainActor
- **NSStatusBar + NSPopover** — full programmatic control (not MenuBarExtra)
- **@Observable** (not ObservableObject) — modern reactivity
- **Zero third-party deps** except SwiftSoup for HTML parsing
- **No Combine** — pure async/await
- **App Sandbox enabled** — App Store compatible
- **Anti-termination** — Info.plist keys + ProcessInfo + applicationShouldTerminate

---

## Roadmap

- [x] Menu bar skeleton + NSPopover
- [x] URL capture + HTML extraction (SwiftSoup)
- [x] Multi-provider LLM (Claude, OpenAI, Ollama)
- [x] Export to 8 apps
- [x] Preferences (provider, API keys, language, shortcut)
- [x] Onboarding + help
- [x] Liquid glass UI
- [x] Search + filters (All/Unread/Summarized/Failed)
- [x] Global shortcut (⌥⌘R, customizable)
- [x] Custom app icon
- [x] i18n English + French
- [x] Delete articles
- [x] Notifications when summary is ready
- [ ] Distribution via Gumroad / Mac App Store
- [ ] Freemium (free tier with Ollama, Pro with cloud providers)

---

## License

MIT — see [LICENSE](LICENSE)

---

Built by [beabot.fr](https://beabot.fr)
