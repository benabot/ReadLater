import SwiftUI
import SwiftData
import UserNotifications

@main
struct ReadLaterAIApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Scène vide — toute l'UI est dans le NSPopover via l'AppDelegate.
        Settings {}
    }
}

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var modelContainer: ModelContainer!
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var currentKeyCode: UInt16 = 0
    private var currentModifiers: UInt = 0
    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        // CRITIQUE : Désactiver l'Automatic Termination.
        // Sans ça, macOS tue l'app quand il n'y a pas de fenêtre visible
        // (ce qui est toujours le cas pour une app menu bar).
        // C'est l'équivalent de "process.on('SIGTERM', () => {})" en Node.js —
        // on dit au système de ne PAS tuer notre process.
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app must stay alive")
        ProcessInfo.processInfo.disableSuddenTermination()

        setupModelContainer()
        setupPopover()
        setupStatusItem()
        loadAndApplyShortcut()
        observeShortcutChanges()
        requestNotificationPermission()
        applyStoredAppearance()
    }

    // MARK: - Prevent Termination

    /// Empêche macOS de quitter l'app quand le popover se ferme.
    /// Sans ça, macOS considère que l'app "n'a plus de raison de vivre"
    /// et la termine (applicationShouldTerminate).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateCancel
    }

    /// Empêche la terminaison quand la dernière fenêtre se ferme.
    /// Par défaut, macOS quitte une app quand sa dernière fenêtre est fermée.
    /// Pour une app menu bar, c'est catastrophique — le popover compte comme une fenêtre.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
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
        popover.animates = true

        let contentView = ContentView(onQuit: {
            // Seule façon de quitter : le bouton "Quitter" explicite.
            // On réactive la terminaison avant de quitter.
            ProcessInfo.processInfo.enableAutomaticTermination("User requested quit")
            ProcessInfo.processInfo.enableSuddenTermination()
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
            // Réappliquer le thème car la window du popover est recréée à chaque ouverture
            applyStoredAppearance()
        }
    }

    // MARK: - Shortcut

    private func loadAndApplyShortcut() {
        let storedModifiers = UInt(UserDefaults.standard.integer(forKey: "shortcutModifiers"))
        let storedKeyCode = UInt16(UserDefaults.standard.integer(forKey: "shortcutKeyCode"))

        let shortcut: ShortcutKey
        if storedModifiers != 0 {
            shortcut = ShortcutKey(keyCode: storedKeyCode, modifiers: storedModifiers)
        } else {
            shortcut = .defaultShortcut
        }

        guard shortcut.keyCode != currentKeyCode || shortcut.modifiers != currentModifiers else {
            return
        }

        currentKeyCode = shortcut.keyCode
        currentModifiers = shortcut.modifiers
        removeShortcutMonitors()

        let reqKey = shortcut.keyCode
        let reqMods = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !ShortcutRecordingState.shared.isRecording else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == reqMods && event.keyCode == reqKey {
                DispatchQueue.main.async { self?.togglePopover() }
            }
        }

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

    private func observeShortcutChanges() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard !ShortcutRecordingState.shared.isRecording else { return }
                self?.loadAndApplyShortcut()
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Appearance

    private func applyStoredAppearance() {
        let mode = UserDefaults.standard.string(forKey: "appAppearance") ?? "system"
        applyAppearance(mode)
    }

    /// Applique le thème sur l'app ET le popover.
    /// NSApp.appearance contrôle les fenêtres classiques mais le NSPopover
    /// peut ne pas hériter automatiquement. On force aussi sur le contentViewController.
    func applyAppearance(_ mode: String) {
        let appearance: NSAppearance?
        switch mode {
        case "light":
            appearance = NSAppearance(named: .aqua)
        case "dark":
            appearance = NSAppearance(named: .darkAqua)
        default:
            appearance = nil
        }
        NSApp.appearance = appearance
        popover?.contentViewController?.view.window?.appearance = appearance
        popover?.contentViewController?.view.appearance = appearance
    }

    private func removeShortcutMonitors() {
        if let gm = globalMonitor { NSEvent.removeMonitor(gm); globalMonitor = nil }
        if let lm = localMonitor { NSEvent.removeMonitor(lm); localMonitor = nil }
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeShortcutMonitors()
        if let obs = defaultsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
