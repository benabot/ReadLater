import SwiftUI
import SwiftData

// MARK: - ReadLaterAIApp
// @main marque le point d'entrée de l'app (comme le `main()` en C ou `createApp()` en Vue).

@main
struct ReadLaterAIApp: App {

    // MARK: - SwiftData Container

    private let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Article.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Impossible de créer le ModelContainer : \(error.localizedDescription)")
        }

        // NOTE: Le raccourci global ⌥⌘R est désactivé pour l'instant.
        // Avec MenuBarExtra(.window), NSApp.activate() provoque un conflit
        // de scènes ("scene-invalidated") qui empêche le popover de s'ouvrir.
        // Pour un vrai raccourci global qui toggle le popover, il faudrait
        // migrer vers NSStatusBar + NSPopover manuellement (refactoring futur).
    }

    // MARK: - App Body

    var body: some Scene {
        MenuBarExtra("ReadLater AI", systemImage: "text.page.badge.magnifyingglass") {
            ContentView(onQuit: {
                NSApplication.shared.terminate(nil)
            })
            .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
