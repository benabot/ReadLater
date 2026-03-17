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
                        title: "Add an article",
                        icon: "plus.circle",
                        items: [
                            HelpItem(gesture: "Paste a URL", description: "Paste a URL in the field above and submit"),
                            HelpItem(gesture: "Copy a URL", description: "Copy a URL in your browser — a blue banner will appear to add it"),
                            HelpItem(gesture: "Safari Import", description: "Click the Safari icon in the footer to import your Reading List"),
                        ]
                    )

                    helpSection(
                        title: "Summarize an article",
                        icon: "sparkles",
                        items: [
                            HelpItem(gesture: "✨ Button", description: "Click the sparkles icon to the right of an article to start the AI summary"),
                            HelpItem(gesture: "Click on the article", description: "Click on a summarized article to show/hide the full summary"),
                        ]
                    )

                    helpSection(
                        title: "Export",
                        icon: "square.and.arrow.up",
                        items: [
                            HelpItem(gesture: "Right-click", description: "Right-click on an article to open the export menu"),
                            HelpItem(gesture: "Supported apps", description: "Bear, iA Writer, Obsidian, Craft, Ulysses, Evernote, Notes, Clipboard"),
                        ]
                    )

                    helpSection(
                        title: "Manage articles",
                        icon: "list.bullet",
                        items: [
                            HelpItem(gesture: "Delete", description: "Swipe an article to the left or use right-click"),
                        ]
                    )

                    helpSection(
                        title: "Indicators",
                        icon: "info.circle",
                        items: [
                            HelpItem(gesture: "✅ Green", description: "Article summarized successfully"),
                            HelpItem(gesture: "⚠️ Orange", description: "Content not extracted (protected site, timeout, etc.)"),
                            HelpItem(gesture: "✨ Purple", description: "Summary available — click to start"),
                        ]
                    )

                    helpSection(
                        title: "Preferences",
                        icon: "gearshape",
                        items: [
                            HelpItem(gesture: "AI Provider", description: "Choose between Ollama (local/free), Claude or OpenAI"),
                            HelpItem(gesture: "API Keys", description: "Configure your API keys — they are encrypted in macOS Keychain"),
                            HelpItem(gesture: "Language", description: "Choose the language for summary generation"),
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
