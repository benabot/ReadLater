import SwiftUI

// MARK: - ExportMenuView
// Menu contextuel qui s'affiche quand on fait clic droit ou long press sur un article.
// Propose les différentes options d'export.
//
// En SwiftUI, `.contextMenu` est l'équivalent du menu clic droit (contextmenu event en JS).
// On l'utilise comme un modifier sur la vue.

struct ExportMenuView: View {
    let article: Article
    var onDelete: (() -> Void)? = nil
    @State private var exportError: String?
    @State private var showCopiedFeedback: Bool = false

    var body: some View {
        VStack {
            // Le contenu sur lequel le menu est attaché n'est pas ici —
            // ce composant est utilisé comme contenu du .contextMenu
            // dans ArticleRowPlaceholder.

            ForEach(ExportService.Target.allCases) { target in
                Button {
                    exportTo(target)
                } label: {
                    Label(target.displayName, systemImage: target.icon)
                }
            }

            Divider()

            // Copier l'URL seule
            Button {
                ExportService.copyToClipboard(markdown: article.url)
            } label: {
                Label("Copy URL", systemImage: "link")
            }

            // Ouvrir dans le navigateur
            Button {
                if let url = URL(string: article.url) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open in browser", systemImage: "safari")
            }

            // Supprimer
            if let onDelete {
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func exportTo(_ target: ExportService.Target) {
        do {
            try ExportService.export(article, to: target)
        } catch {
            exportError = error.localizedDescription
        }
    }
}
