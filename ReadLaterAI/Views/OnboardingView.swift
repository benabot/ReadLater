import SwiftUI

// MARK: - OnboardingView
// Page de bienvenue affichée au premier lancement de l'app.
// Présente les fonctionnalités principales en 4 étapes illustrées.
//
// Utilise @AppStorage("hasSeenOnboarding") pour ne s'afficher qu'une fois.
// C'est le même pattern que les "welcome screens" dans les apps iOS/macOS.

struct OnboardingView: View {

    let onDismiss: () -> Void

    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "text.page.badge.magnifyingglass",
            title: "Bienvenue dans ReadLater AI",
            subtitle: "Capturez, résumez et exportez vos articles en un clic",
            features: []
        ),
        OnboardingPage(
            icon: "link.badge.plus",
            title: "Capturez vos articles",
            subtitle: "",
            features: [
                Feature(icon: "doc.on.clipboard", text: "Collez une URL ou copiez-la — elle sera détectée automatiquement"),
                Feature(icon: "safari", text: "Importez votre Reading List Safari en un clic"),
                Feature(icon: "globe", text: "Le contenu est extrait et nettoyé automatiquement"),
            ]
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Résumez avec l'IA",
            subtitle: "",
            features: [
                Feature(icon: "brain", text: "Claude, OpenAI ou Ollama — choisissez votre provider"),
                Feature(icon: "text.quote", text: "TL;DR, points clés, temps de lecture et tags"),
                Feature(icon: "key", text: "Clés API chiffrées dans le Keychain macOS"),
            ]
        ),
        OnboardingPage(
            icon: "square.and.arrow.up",
            title: "Exportez partout",
            subtitle: "",
            features: [
                Feature(icon: "text.book.closed", text: "Bear, iA Writer, Obsidian, Craft, Ulysses…"),
                Feature(icon: "doc.on.doc", text: "Copier en Markdown dans le presse-papiers"),
                Feature(icon: "cursorarrow.click.2", text: "Clic droit sur un article pour exporter"),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Contenu de la page
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation en bas
            bottomBar
        }
    }

    // MARK: - Page Content

    private var pageContent: some View {
        VStack(spacing: 16) {
            Spacer()

            // Icône principale
            Image(systemName: pages[currentPage].icon)
                .font(.system(size: 40))
                .foregroundStyle(currentPage == 0 ? Color.accentColor : Color.purple)
                .padding(.bottom, 4)

            // Titre
            Text(pages[currentPage].title)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Sous-titre (page 0 uniquement)
            if !pages[currentPage].subtitle.isEmpty {
                Text(pages[currentPage].subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Features
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
                                .foregroundStyle(.primary)
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Bouton "Passer"
            if currentPage < pages.count - 1 {
                Button("Passer") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Spacer()
            }

            Spacer()

            // Indicateurs de page (dots)
            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            // Bouton Suivant / C'est parti
            if currentPage < pages.count - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage += 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Suivant")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 4) {
                        Text("C'est parti !")
                        Image(systemName: "arrow.right")
                            .font(.caption)
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

// MARK: - Data Models

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
