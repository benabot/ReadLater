import SwiftUI
import SwiftData
import UserNotifications

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
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app must stay alive")
        ProcessInfo.processInfo.disableSuddenTermination()

        setupModelContainer()
        setupPopover()
        setupStatusItem()
        loadAndApplyShortcut()
        observeShortcutChanges()
        requestNotificationPermission()
    }

    // MARK: - Prevent Termination

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
        }
    }

    // MARK: - Shortcut

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

        // Toujours recréer les monitors (pas de guard)
        // Le guard précédent empêchait la recréation quand on revenait au raccourci par défaut
        removeShortcutMonitors()

        let reqKey = shortcut.keyCode
        let reqMods = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)

        print("[ReadLater] Shortcut loaded: \(shortcut.displayString) (key=\(reqKey), mods=\(reqMods.rawValue))")

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

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
