import SwiftUI
import SwiftData

// MARK: - ReadLaterAIApp
// Point d'entrée de l'app.
//
// MIGRATION de MenuBarExtra vers NSStatusBar + NSPopover :
// MenuBarExtra(.window) ne permet pas de toggle le popover par code,
// ce qui empêche le raccourci global de fonctionner.
// On utilise donc l'API AppKit classique avec un AppDelegate.
//
// L'architecture est :
// - @main App crée la scène (vide, pas de fenêtre)
// - AppDelegate gère le NSStatusItem (icône menu bar) + NSPopover
// - Le raccourci global toggle le popover via l'AppDelegate
//
// C'est le pattern utilisé par les apps menu bar pros
// (Raycast, CleanShot, Bartender, etc.)

@main
struct ReadLaterAIApp: App {

    // @NSApplicationDelegateAdaptor connecte un AppDelegate AppKit à une app SwiftUI.
    // C'est le pont entre le monde SwiftUI (déclaratif) et AppKit (impératif).
    // En web, c'est comme mixer Vue.js (déclaratif) avec du jQuery (impératif).
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings {} crée une scène vide — pas de fenêtre, pas de Dock icon.
        // L'UI est entièrement gérée par le NSPopover dans l'AppDelegate.
        Settings {}
    }
}

// MARK: - AppDelegate
// Gère le cycle de vie AppKit : status bar, popover, raccourci global.
//
// NSApplicationDelegate est le protocol AppKit pour recevoir les événements
// de l'application (lancement, terminaison, activation, etc.).
// C'est l'équivalent des lifecycle hooks en Vue (created, mounted, destroyed).

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Propriétés

    /// L'icône dans la menu bar. NSStatusItem est l'API bas-niveau
    /// pour ajouter un élément dans la barre de menus macOS.
    private var statusItem: NSStatusItem!

    /// Le popover qui s'affiche au clic sur l'icône.
    /// NSPopover est une bulle attachée à un point d'ancrage (ici, l'icône).
    private var popover: NSPopover!

    /// Le conteneur SwiftData (base de données).
    private var modelContainer: ModelContainer!

    /// Le gestionnaire de raccourci global.
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// Monitor pour fermer le popover quand on clique en dehors.
    /// C'est l'équivalent d'un `addEventListener("click", closeOnClickOutside)` sur document.
    private var clickOutsideMonitor: Any?

    // MARK: - App Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Créer le ModelContainer SwiftData
        setupModelContainer()

        // 2. Créer le popover avec le ContentView SwiftUI
        setupPopover()

        // 3. Créer l'icône dans la menu bar
        setupStatusItem()

        // 4. Enregistrer le raccourci global
        setupGlobalShortcut()
    }

    // MARK: - SwiftData Setup

    private func setupModelContainer() {
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
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }

    // MARK: - Popover Setup

    private func setupPopover() {
        popover = NSPopover()

        // .transient = le popover se ferme automatiquement quand on clique en dehors.
        // C'est le comportement attendu pour une app menu bar.
        // Les autres options sont .semitransient et .applicationDefined.
        popover.behavior = .transient

        // Le contenu du popover est notre ContentView SwiftUI.
        // NSHostingView encapsule une vue SwiftUI dans une NSView AppKit.
        // C'est le pont SwiftUI → AppKit (l'inverse de UIViewRepresentable).
        let contentView = ContentView(onQuit: {
            NSApplication.shared.terminate(nil)
        })
        .modelContainer(self.modelContainer)

        popover.contentViewController = NSHostingController(rootView: contentView)

        // Taille du popover
        popover.contentSize = NSSize(width: 400, height: 540)
    }

    // MARK: - Status Bar Setup

    private func setupStatusItem() {
        // NSStatusBar.system.statusItem crée un élément dans la menu bar.
        // .variableLength = la largeur s'adapte au contenu.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configurer le bouton (l'icône cliquable).
        if let button = statusItem.button {
            // SF Symbol comme icône
            button.image = NSImage(systemSymbolName: "text.page.badge.magnifyingglass", accessibilityDescription: "ReadLater AI")

            // Action au clic : toggle le popover.
            // #selector est la syntaxe Objective-C pour référencer une méthode.
            // C'est hérité de l'époque pré-Swift et toujours nécessaire pour
            // les actions AppKit (comme addEventListener en JS).
            button.action = #selector(togglePopover)

            // target = self signifie que c'est CETTE instance d'AppDelegate
            // qui reçoit l'appel. Sans ça, AppKit cherche dans la "responder chain".
            button.target = self
        }
    }

    // MARK: - Toggle Popover

    /// Ouvre ou ferme le popover.
    /// @objc est nécessaire pour que la méthode soit visible par le runtime Objective-C
    /// (requis par #selector). C'est un vestige historique de l'interop Swift/ObjC.
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            openPopover(relativeTo: button)
        }
    }

    private func openPopover(relativeTo button: NSStatusBarButton) {
        // Afficher le popover sous le bouton de la menu bar.
        // .minY = le popover apparaît en dessous (comme un dropdown).
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Activer l'app pour que le popover reçoive le focus clavier.
        // Sans ça, le champ texte ne serait pas focusable.
        NSApp.activate(ignoringOtherApps: true)

        // Installer un monitor pour fermer quand on clique en dehors.
        // C'est un "click outside to close" comme en web.
        installClickOutsideMonitor()
    }

    private func closePopover() {
        popover.performClose(nil)
        removeClickOutsideMonitor()
    }

    // MARK: - Click Outside Monitor

    /// Ferme le popover quand l'utilisateur clique en dehors.
    /// addGlobalMonitorForEvents écoute les clics dans TOUTES les apps.
    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    // MARK: - Global Shortcut

    /// Enregistre le raccourci global qui toggle le popover.
    /// Lit la configuration depuis UserDefaults (modifiable dans les Préférences).
    private func setupGlobalShortcut() {
        let keyCode = UInt16(UserDefaults.standard.integer(forKey: "shortcutKeyCode"))
        let modifiers = UInt(UserDefaults.standard.integer(forKey: "shortcutModifiers"))

        // Si pas de raccourci configuré, utiliser le défaut ⌥⌘R
        let shortcut: ShortcutKey
        if modifiers != 0 {
            shortcut = ShortcutKey(keyCode: keyCode, modifiers: modifiers)
        } else {
            shortcut = .defaultShortcut
        }

        let requiredKeyCode = shortcut.keyCode
        let requiredModifiers = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)

        // Monitor GLOBAL — capte les touches quand l'app N'EST PAS au premier plan.
        // C'est le cas principal : l'utilisateur est dans Safari et appuie sur ⌥⌘R.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == requiredModifiers && event.keyCode == requiredKeyCode {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }

        // Monitor LOCAL — capte les touches quand l'app EST au premier plan.
        // Utile pour fermer le popover avec le même raccourci.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == requiredModifiers && event.keyCode == requiredKeyCode {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
                return nil  // Consommer l'événement
            }
            return event
        }

        // Observer les changements de raccourci dans les Préférences.
        // Quand l'utilisateur change le raccourci, on réenregistre les monitors.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadShortcut()
        }
    }

    /// Recharge le raccourci quand les préférences changent.
    private func reloadShortcut() {
        // Supprimer les anciens monitors
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
        globalMonitor = nil
        localMonitor = nil

        // Réenregistrer avec les nouvelles valeurs
        setupGlobalShortcut()
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
        removeClickOutsideMonitor()
    }
}
