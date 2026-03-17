import SwiftUI
import SwiftData

@main
struct ReadLaterAIApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {}
    }
}

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var modelContainer: ModelContainer!

    // Raccourci global — monitors séparés
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // Valeurs actuelles du raccourci (pour détecter les vrais changements)
    private var currentKeyCode: UInt16 = 0
    private var currentModifiers: UInt = 0

    // Observer UserDefaults (stocké pour pouvoir le retirer)
    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupPopover()
        setupStatusItem()
        loadAndApplyShortcut()
        observeShortcutChanges()
    }

    // MARK: - SwiftData

    private func setupModelContainer() {
        do {
            let schema = Schema([Article.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 400, height: 540)

        let contentView = ContentView(onQuit: {
            NSApplication.shared.terminate(nil)
        })
        .modelContainer(self.modelContainer)

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "text.page.badge.magnifyingglass",
                accessibilityDescription: "ReadLater AI"
            )
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    // MARK: - Toggle Popover

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Shortcut Management

    /// Lit le raccourci depuis UserDefaults et installe les monitors.
    private func loadAndApplyShortcut() {
        let storedModifiers = UInt(UserDefaults.standard.integer(forKey: "shortcutModifiers"))
        let storedKeyCode = UInt16(UserDefaults.standard.integer(forKey: "shortcutKeyCode"))

        // Utiliser le défaut ⌥⌘R si rien n'est configuré
        let shortcut: ShortcutKey
        if storedModifiers != 0 {
            shortcut = ShortcutKey(keyCode: storedKeyCode, modifiers: storedModifiers)
        } else {
            shortcut = .defaultShortcut
        }

        // Ne rien faire si le raccourci n'a pas changé
        guard shortcut.keyCode != currentKeyCode || shortcut.modifiers != currentModifiers else {
            return
        }

        currentKeyCode = shortcut.keyCode
        currentModifiers = shortcut.modifiers

        // Retirer les anciens monitors
        removeShortcutMonitors()

        // Installer les nouveaux
        let reqKey = shortcut.keyCode
        let reqMods = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)

        // Global — quand l'app n'est PAS au premier plan
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !ShortcutRecordingState.shared.isRecording else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == reqMods && event.keyCode == reqKey {
                DispatchQueue.main.async { self?.togglePopover() }
            }
        }

        // Local — quand l'app EST au premier plan
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !ShortcutRecordingState.shared.isRecording else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == reqMods && event.keyCode == reqKey {
                DispatchQueue.main.async { self?.togglePopover() }
                return nil
            }
            return event
        }
    }

    /// Observe uniquement les changements de raccourci (pas tous les UserDefaults).
    private func observeShortcutChanges() {
        // On observe UserDefaults.didChangeNotification mais on ne recharge
        // que si les clés du raccourci ont réellement changé (grâce au guard
        // dans loadAndApplyShortcut).
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Ignorer pendant l'enregistrement d'un nouveau raccourci
            guard !ShortcutRecordingState.shared.isRecording else { return }
            self?.loadAndApplyShortcut()
        }
    }

    private func removeShortcutMonitors() {
        if let gm = globalMonitor { NSEvent.removeMonitor(gm); globalMonitor = nil }
        if let lm = localMonitor { NSEvent.removeMonitor(lm); localMonitor = nil }
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        removeShortcutMonitors()
        if let obs = defaultsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
