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

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app must stay alive")
        ProcessInfo.processInfo.disableSuddenTermination()

        setupModelContainer()
        setupPopover()
        setupStatusItem()
        setupShortcut()
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

    // MARK: - Global Shortcut ⌥⌘R (hardcoded)
    // Un seul raccourci fixe, enregistré une fois au lancement.
    // Pas de UserDefaults, pas d'observer, pas de recreation dynamique.

    private func setupShortcut() {
        let reqKey: UInt16 = 15  // kVK_ANSI_R
        let reqMods: NSEvent.ModifierFlags = [.option, .command]

        // Global — quand l'app n'est PAS au premier plan (ex: utilisateur dans Safari)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == reqKey && mods == reqMods {
                DispatchQueue.main.async { self?.togglePopover() }
            }
        }

        // Local — quand l'app EST au premier plan (pour fermer avec le même raccourci)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == reqKey && mods == reqMods {
                DispatchQueue.main.async { self?.togglePopover() }
                return nil
            }
            return event
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
    }
}
