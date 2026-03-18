import SwiftUI
import ApplicationServices

// MARK: - PreferencesView

struct PreferencesView: View {

    let onDismiss: () -> Void

    enum Tab: String, CaseIterable {
        case ai = "AI"
        case general = "General"

        var icon: String {
            switch self {
            case .ai: "brain"
            case .general: "gearshape"
            }
        }
    }

    @State private var selectedTab: Tab = .ai
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            GlassDivider()
            tabBar
            GlassDivider()

            // Contenu selon l'onglet — PAS dans un switch à l'intérieur d'un ScrollView
            // (le switch dans ScrollView peut causer des problèmes de navigation).
            // On affiche les deux et on masque celui qui n'est pas actif.
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == .ai {
                        AISettingsSection(
                            onStatus: { message, isError in
                                showStatus(message, isError: isError)
                            }
                        )
                    }
                    if selectedTab == .general {
                        GeneralSettingsSection()
                    }
                }
                .padding(14)
            }

            if let message = statusMessage {
                Divider()
                statusBar(message: message)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Preferences", systemImage: "gearshape.fill")
                .font(.headline)
            Spacer()
            Button("Back") { onDismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.callout)
                        Text(tab.rawValue)
                            .font(.callout)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == tab
                                  ? Color.accentColor.opacity(0.12)
                                  : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedTab == tab
                                            ? Color.accentColor.opacity(0.2)
                                            : Color.clear, lineWidth: 0.5)
                            )
                    )
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Status Bar

    private func statusBar(message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(statusIsError ? .red : .green)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        withAnimation {
            statusMessage = message
            statusIsError = isError
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { statusMessage = nil }
        }
    }
}

// MARK: - AI Settings Section

struct AISettingsSection: View {

    var onStatus: (String, Bool) -> Void

    @AppStorage("selectedProvider") private var selectedProvider: String = "ollama"
    @AppStorage("ollamaModel") private var ollamaModel: String = "llama3.2"
    @AppStorage("ollamaURL") private var ollamaURL: String = "http://localhost:11434"

    @State private var claudeKey: String = ""
    @State private var openAIKey: String = ""
    @State private var claudeKeySaved: Bool = false
    @State private var openAIKeySaved: Bool = false
    @State private var isCheckingOllama: Bool = false
    @State private var ollamaStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            providerCard
            Divider()
            apiKeysCard
            Divider()
            ollamaCard
        }
        .onAppear {
            claudeKeySaved = KeychainService.hasKey(for: .claude)
            openAIKeySaved = KeychainService.hasKey(for: .openAI)
        }
    }

    // MARK: - Provider Card

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI Provider", systemImage: "cpu")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(providerOptions, id: \.id) { option in
                providerRow(option)
            }
        }
    }

    private struct ProviderOption: Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String
        let needsKey: Bool
    }

    private var providerOptions: [ProviderOption] {
        [
            ProviderOption(id: "ollama", name: "Ollama", description: String(localized: "Local, free, private"), icon: "desktopcomputer", needsKey: false),
            ProviderOption(id: "claude", name: "Claude", description: "Anthropic API", icon: "brain", needsKey: true),
            ProviderOption(id: "openai", name: "OpenAI", description: "GPT-4o-mini", icon: "globe", needsKey: true),
        ]
    }

    private func providerRow(_ option: ProviderOption) -> some View {
        Button {
            selectedProvider = option.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selectedProvider == option.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedProvider == option.id ? Color.blue : Color.gray.opacity(0.3))
                    .font(.body)

                Image(systemName: option.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(.body)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if option.needsKey {
                    let hasKey = option.id == "claude" ? claudeKeySaved : openAIKeySaved
                    Image(systemName: hasKey ? "key.fill" : "key")
                        .font(.caption)
                        .foregroundStyle(hasKey ? .green : .orange)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedProvider == option.id
                          ? Color.accentColor.opacity(0.08)
                          : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedProvider == option.id
                            ? Color.accentColor.opacity(0.3)
                            : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - API Keys Card

    private var apiKeysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Keys", systemImage: "key.fill")
                .font(.subheadline)
                .fontWeight(.semibold)

            apiKeyRow(
                name: "Claude (Anthropic)",
                placeholder: "sk-ant-api03-...",
                key: $claudeKey,
                isSaved: $claudeKeySaved,
                keychainKey: .claude
            )

            apiKeyRow(
                name: "OpenAI",
                placeholder: "sk-...",
                key: $openAIKey,
                isSaved: $openAIKeySaved,
                keychainKey: .openAI
            )

            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                Text("Keys encrypted in macOS Keychain")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func apiKeyRow(
        name: String,
        placeholder: String,
        key: Binding<String>,
        isSaved: Binding<Bool>,
        keychainKey: KeychainService.Key
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.body)
                Spacer()
                if isSaved.wrappedValue {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Active")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }

            HStack(spacing: 8) {
                SecureField(placeholder, text: key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Button(isSaved.wrappedValue ? String(localized: "Edit") : String(localized: "Save")) {
                    do {
                        try KeychainService.save(apiKey: key.wrappedValue, for: keychainKey)
                        key.wrappedValue = ""
                        isSaved.wrappedValue = true
                        onStatus(String(localized: "Key \(name) saved ✓"), false)
                    } catch {
                        onStatus(error.localizedDescription, true)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(key.wrappedValue.isEmpty)

                if isSaved.wrappedValue {
                    Button {
                        do {
                            try KeychainService.delete(for: keychainKey)
                            isSaved.wrappedValue = false
                            onStatus(String(localized: "Key \(name) deleted"), false)
                        } catch {
                            onStatus(error.localizedDescription, true)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Ollama Card

    private var ollamaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ollama (local)", systemImage: "server.rack")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("URL")
                        .font(.body)
                        .frame(width: 50, alignment: .trailing)
                    TextField("http://localhost:11434", text: $ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 8) {
                    Text("Model")
                        .font(.body)
                        .frame(width: 50, alignment: .trailing)
                    TextField("llama3.2", text: $ollamaModel)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                HStack(spacing: 8) {
                    Button {
                        checkOllama()
                    } label: {
                        HStack(spacing: 5) {
                            if isCheckingOllama {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.caption)
                            }
                            Text("Test connection")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isCheckingOllama)

                    if let status = ollamaStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(status.contains("✓") ? .green : .orange)
                    }
                }
            }

            Text("brew install ollama && ollama pull llama3.2")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func checkOllama() {
        isCheckingOllama = true
        ollamaStatus = nil
        Task {
            guard let url = URL(string: "\(ollamaURL)/api/tags") else {
                ollamaStatus = String(localized: "Invalid URL")
                isCheckingOllama = false
                return
            }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 3
                let (data, response) = try await URLSession.shared.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let models = json["models"] as? [[String: Any]] {
                        let names = models.compactMap { $0["name"] as? String }
                        ollamaStatus = "✓ \(names.count) model\(names.count > 1 ? "s" : "")"
                    } else {
                        ollamaStatus = String(localized: "Connected ✓")
                    }
                } else {
                    ollamaStatus = String(localized: "HTTP Error")
                }
            } catch {
                ollamaStatus = String(localized: "Offline")
            }
            isCheckingOllama = false
        }
    }
}

// MARK: - General Settings Section

struct GeneralSettingsSection: View {

    @AppStorage("summaryLanguage") private var summaryLanguage: String = "français"
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode: Int = 15
    @AppStorage("shortcutModifiers") private var shortcutModifiers: Int = 0
    @AppStorage("appAppearance") private var appAppearance: String = "system"

    @State private var currentShortcut: ShortcutKey = .defaultShortcut

    private let languages = [
        ("français", "🇫🇷 Français"),
        ("english", "🇬🇧 English"),
        ("español", "🇪🇸 Español"),
        ("deutsch", "🇩🇪 Deutsch"),
        ("italiano", "🇮🇹 Italiano"),
        ("português", "🇵🇹 Português"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            languageCard
            Divider()
            appearanceCard
            Divider()
            shortcutCard
            Divider()
            aboutCard
        }
        .onAppear {
            if shortcutModifiers != 0 {
                currentShortcut = ShortcutKey(
                    keyCode: UInt16(shortcutKeyCode),
                    modifiers: UInt(shortcutModifiers)
                )
            }
        }
        .onChange(of: currentShortcut) {
            shortcutKeyCode = Int(currentShortcut.keyCode)
            shortcutModifiers = Int(currentShortcut.modifiers)
        }
    }

    // MARK: - Langue

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Summary language", systemImage: "globe")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(languages, id: \.0) { (code, label) in
                    Button {
                        summaryLanguage = code
                    } label: {
                        Text(label)
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(summaryLanguage == code
                                          ? Color.accentColor.opacity(0.12)
                                          : Color.primary.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(summaryLanguage == code
                                            ? Color.accentColor.opacity(0.3)
                                            : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(summaryLanguage == code ? .primary : .secondary)
                }
            }

            Text("AI summaries will be generated in this language")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Apparence

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Appearance", systemImage: "paintbrush")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Picker segmenté : System / Light / Dark
            // C'est comme un groupe de radio buttons en HTML.
            Picker("", selection: $appAppearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .onChange(of: appAppearance) { _, newValue in
                applyAppearance(newValue)
            }
        }
    }

    private func applyAppearance(_ mode: String) {
        // Appeler l'AppDelegate qui applique le thème sur l'app ET le popover.
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.applyAppearance(mode)
        }
    }

    // MARK: - Raccourci

    private var shortcutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Global shortcut", systemImage: "keyboard")
                .font(.subheadline)
                .fontWeight(.semibold)

            ShortcutRecorderView(shortcut: $currentShortcut)

            Text("This shortcut activates the app from any application")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Vérifier la permission Accessibilité (nécessaire pour le raccourci global)
            if !AXIsProcessTrusted() {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Accessibility permission required")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Open Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.08))
                )
            }
        }
    }

    // MARK: - À propos

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("About", systemImage: "info.circle")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ReadLater AI")
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    Text("v0.2.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Capture, summarize and export your articles")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Link("GitHub", destination: URL(string: "https://github.com/benabot/ReadLater")!)
                    Link("Site web", destination: URL(string: "https://beabot.fr")!)
                }
                .font(.caption)
            }
        }
    }
}
