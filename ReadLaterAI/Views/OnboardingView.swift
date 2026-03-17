import SwiftUI

struct OnboardingView: View {

    let onDismiss: () -> Void
    @State private var currentPage: Int = 0

    // Les chaînes sont wrappées dans String(localized:) pour que le système
    // de localisation d'Apple les traduise. Sans ça, les strings dans un tableau
    // de structs ne sont PAS localisées automatiquement par SwiftUI
    // (seuls les Text("littéral") le sont).
    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "text.page.badge.magnifyingglass",
                title: String(localized: "Welcome to ReadLater AI"),
                subtitle: String(localized: "Capture, summarize and export your articles in one click"),
                features: []
            ),
            OnboardingPage(
                icon: "link.badge.plus",
                title: String(localized: "Capture your articles"),
                subtitle: "",
                features: [
                    Feature(icon: "doc.on.clipboard", text: String(localized: "Paste a URL or copy it — it will be detected automatically")),
                    Feature(icon: "safari", text: String(localized: "Import your Safari Reading List in one click")),
                    Feature(icon: "globe", text: String(localized: "Content is extracted and cleaned automatically")),
                ]
            ),
            OnboardingPage(
                icon: "sparkles",
                title: String(localized: "Summarize with AI"),
                subtitle: "",
                features: [
                    Feature(icon: "brain", text: String(localized: "Claude, OpenAI or Ollama — choose your provider")),
                    Feature(icon: "text.quote", text: String(localized: "TL;DR, key points, reading time and tags")),
                    Feature(icon: "key", text: String(localized: "API keys encrypted in macOS Keychain")),
                ]
            ),
            OnboardingPage(
                icon: "square.and.arrow.up",
                title: String(localized: "Export everywhere"),
                subtitle: "",
                features: [
                    Feature(icon: "text.book.closed", text: String(localized: "Bear, iA Writer, Obsidian, Craft, Ulysses…")),
                    Feature(icon: "doc.on.doc", text: String(localized: "Copy as Markdown to clipboard")),
                    Feature(icon: "cursorarrow.click.2", text: String(localized: "Right-click on an article to export")),
                ]
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            bottomBar
        }
    }

    private var pageContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: pages[currentPage].icon)
                .font(.system(size: 40))
                .foregroundStyle(currentPage == 0 ? Color.accentColor : Color.purple)
                .padding(.bottom, 4)

            Text(pages[currentPage].title)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if !pages[currentPage].subtitle.isEmpty {
                Text(pages[currentPage].subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if !pages[currentPage].features.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(pages[currentPage].features) { feature in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: feature.icon)
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24, alignment: .center)
                            Text(feature.text)
                                .font(.callout)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var bottomBar: some View {
        HStack {
            if currentPage < pages.count - 1 {
                Button("Skip") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            } else {
                Spacer()
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            if currentPage < pages.count - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { currentPage += 1 }
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right").font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 4) {
                        Text("Let's go!")
                        Image(systemName: "arrow.right").font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let features: [Feature]
}

private struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}
