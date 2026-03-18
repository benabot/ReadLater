import SwiftUI

struct HelpView: View {

    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("User Guide", systemImage: "questionmark.circle.fill")
                    .font(.headline)
                Spacer()
                Button("Back") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(
                        title: String(localized: "Add an article"),
                        icon: "plus.circle",
                        items: [
                            HelpItem(gesture: String(localized: "Paste a URL"), description: String(localized: "Paste a URL in the field above and submit")),
                            HelpItem(gesture: String(localized: "Copy a URL"), description: String(localized: "Copy a URL in your browser — a blue banner will appear to add it")),
                            HelpItem(gesture: String(localized: "Safari Import"), description: String(localized: "Click the Safari icon in the footer to import your Reading List")),
                        ]
                    )

                    helpSection(
                        title: String(localized: "Summarize an article"),
                        icon: "sparkles",
                        items: [
                            HelpItem(gesture: String(localized: "✨ Button"), description: String(localized: "Click the sparkles icon to the right of an article to start the AI summary")),
                            HelpItem(gesture: String(localized: "Click on the article"), description: String(localized: "Click on a summarized article to show/hide the full summary")),
                        ]
                    )

                    helpSection(
                        title: String(localized: "Export"),
                        icon: "square.and.arrow.up",
                        items: [
                            HelpItem(gesture: String(localized: "Right-click"), description: String(localized: "Right-click on an article to open the export menu")),
                            HelpItem(gesture: String(localized: "Supported apps"), description: "Bear, iA Writer, Obsidian, Craft, Ulysses, Evernote, Notes, Clipboard"),
                        ]
                    )

                    helpSection(
                        title: String(localized: "Manage articles"),
                        icon: "list.bullet",
                        items: [
                            HelpItem(gesture: String(localized: "Delete"), description: String(localized: "Swipe an article to the left or use right-click")),
                        ]
                    )

                    helpSection(
                        title: String(localized: "Indicators"),
                        icon: "info.circle",
                        items: [
                            HelpItem(gesture: String(localized: "✅ Green"), description: String(localized: "Article summarized successfully")),
                            HelpItem(gesture: String(localized: "⚠️ Orange"), description: String(localized: "Content not extracted (protected site, timeout, etc.)")),
                            HelpItem(gesture: String(localized: "✨ Purple"), description: String(localized: "Summary available — click to start")),
                        ]
                    )

                    helpSection(
                        title: "Preferences",
                        icon: "gearshape",
                        items: [
                            HelpItem(gesture: String(localized: "AI Provider"), description: String(localized: "Choose between Ollama (local/free), Claude or OpenAI")),
                            HelpItem(gesture: String(localized: "API Keys"), description: String(localized: "Configure your API keys — they are encrypted in macOS Keychain")),
                            HelpItem(gesture: String(localized: "Language"), description: String(localized: "Choose the language for summary generation")),
                        ]
                    )

                    Button {
                        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                        onDismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Review the welcome presentation")
                        }
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(14)
            }
        }
    }

    private func helpSection(title: String, icon: String, items: [HelpItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(item.gesture)
                            .font(.callout)
                            .fontWeight(.medium)
                            .frame(width: 110, alignment: .trailing)
                            .foregroundStyle(Color.accentColor)
                        Text(item.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct HelpItem: Identifiable {
    let id = UUID()
    let gesture: String
    let description: String
}
