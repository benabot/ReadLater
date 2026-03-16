import SwiftUI

// MARK: - HelpView
// Page mode d'emploi inline (dans le popover).
// Accessible via un bouton "?" dans le footer.
// Présente les raccourcis et gestes disponibles dans l'app.

struct HelpView: View {

    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Mode d'emploi", systemImage: "questionmark.circle.fill")
                    .font(.headline)
                Spacer()
                Button("Retour") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpSection(
                        title: "Ajouter un article",
                        icon: "plus.circle",
                        items: [
                            HelpItem(gesture: "Coller une URL", description: "Collez une URL dans le champ en haut et validez"),
                            HelpItem(gesture: "Copier une URL", description: "Copiez une URL dans votre navigateur — une bannière bleue apparaîtra pour l'ajouter"),
                            HelpItem(gesture: "Import Safari", description: "Cliquez sur l'icône Safari dans le footer pour importer votre Reading List"),
                        ]
                    )

                    helpSection(
                        title: "Résumer un article",
                        icon: "sparkles",
                        items: [
                            HelpItem(gesture: "Bouton ✨", description: "Cliquez sur l'icône sparkles à droite d'un article pour lancer le résumé IA"),
                            HelpItem(gesture: "Cliquer sur l'article", description: "Cliquez sur un article résumé pour afficher/masquer le résumé complet"),
                        ]
                    )

                    helpSection(
                        title: "Exporter",
                        icon: "square.and.arrow.up",
                        items: [
                            HelpItem(gesture: "Clic droit", description: "Faites un clic droit sur un article pour ouvrir le menu d'export"),
                            HelpItem(gesture: "Apps supportées", description: "Bear, iA Writer, Obsidian, Craft, Ulysses, Evernote, Notes, Clipboard"),
                        ]
                    )

                    helpSection(
                        title: "Gérer les articles",
                        icon: "list.bullet",
                        items: [
                            HelpItem(gesture: "Supprimer", description: "Glissez un article vers la gauche ou utilisez le clic droit"),
                        ]
                    )

                    helpSection(
                        title: "Indicateurs",
                        icon: "info.circle",
                        items: [
                            HelpItem(gesture: "✅ Vert", description: "Article résumé avec succès"),
                            HelpItem(gesture: "⚠️ Orange", description: "Contenu non extrait (site protégé, timeout, etc.)"),
                            HelpItem(gesture: "✨ Violet", description: "Résumé disponible — cliquez pour lancer"),
                        ]
                    )

                    helpSection(
                        title: "Préférences",
                        icon: "gearshape",
                        items: [
                            HelpItem(gesture: "Provider IA", description: "Choisissez entre Ollama (local/gratuit), Claude ou OpenAI"),
                            HelpItem(gesture: "Clés API", description: "Configurez vos clés API — elles sont chiffrées dans le Keychain macOS"),
                            HelpItem(gesture: "Langue", description: "Choisissez la langue de génération des résumés"),
                        ]
                    )

                    // Lien revoir l'onboarding
                    Button {
                        // Reset le flag d'onboarding pour le revoir
                        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                        onDismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Revoir la présentation de bienvenue")
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

    // MARK: - Section

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

// MARK: - HelpItem

private struct HelpItem: Identifiable {
    let id = UUID()
    let gesture: String
    let description: String
}
