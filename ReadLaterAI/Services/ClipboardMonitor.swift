import AppKit
import SwiftUI  // pour withAnimation

// MARK: - ClipboardMonitor
// Service qui surveille le presse-papiers macOS pour détecter quand l'utilisateur
// copie une URL. C'est comme un "watcher" en Vue ou un MutationObserver en JS.
//
// macOS n'a PAS de notification native "le clipboard a changé" (contrairement à iOS).
// On utilise donc un Timer qui poll le clipboard toutes les 2 secondes.
// NSPasteboard.changeCount s'incrémente à chaque modification du clipboard.
//
// @Observable est le nouveau pattern de réactivité de Swift (macOS 14+).
// C'est l'équivalent de `reactive()` en Vue 3 : quand une propriété change,
// toutes les vues qui l'utilisent se mettent à jour automatiquement.
//
// @MainActor force l'exécution sur le thread principal (main thread).
// En Swift, toucher à l'UI ou à AppKit depuis un thread secondaire = crash.

@MainActor
@Observable
final class ClipboardMonitor {

    // MARK: - Propriétés observables

    /// L'URL détectée dans le clipboard, prête à être consommée par la vue.
    var detectedURL: String?

    /// Indique si la surveillance est active.
    var isMonitoring: Bool = false

    // MARK: - État interne

    /// Le dernier changeCount connu du clipboard.
    private var lastChangeCount: Int = 0

    /// Le Timer qui poll le clipboard.
    /// En Swift, Timer? signifie "un Timer ou nil" (Optional).
    private var pollTimer: Timer?

    /// Intervalle de polling en secondes.
    private let pollInterval: TimeInterval = 2.0

    /// URLs déjà détectées (pour éviter les doublons).
    /// Set<String> est un ensemble non-ordonné sans doublons (comme un Set en JS).
    private var seenURLs: Set<String> = []

    // MARK: - Lifecycle

    /// Démarre la surveillance du clipboard.
    func start() {
        guard !isMonitoring else { return }

        lastChangeCount = NSPasteboard.general.changeCount
        isMonitoring = true

        // Timer.scheduledTimer est l'équivalent de setInterval() en JS.
        //
        // === EXPLICATION [weak self] ===
        // En Swift, la mémoire est gérée par ARC (Automatic Reference Counting).
        // Si le Timer capture `self` (notre ClipboardMonitor), il crée une
        // "retain cycle" (référence circulaire) :
        //   ClipboardMonitor → Timer → closure → ClipboardMonitor (boucle!)
        //
        // `[weak self]` dit : "ne compte PAS cette référence dans le compteur ARC".
        // Quand le ClipboardMonitor est détruit, self devient nil dans le closure.
        //
        // Analogie JS : c'est comme un eventListener qui empêcherait le garbage
        // collector de libérer l'objet parent. En JS on fait removeEventListener.
        // En Swift, [weak self] fait le même job.
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.checkClipboard()
            }
        }
    }

    /// Arrête la surveillance.
    /// Note : pas de `deinit` ici car en Swift 6 strict concurrency,
    /// deinit ne peut pas accéder aux propriétés @MainActor.
    /// On s'appuie sur le cycle de vie SwiftUI (.task annule au démontage).
    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        isMonitoring = false
    }

    /// Réinitialise l'URL détectée (après qu'elle a été consommée par la vue).
    func clearDetectedURL() {
        detectedURL = nil
    }

    /// Ajoute une URL à la liste des URLs déjà vues (pour éviter de la re-détecter).
    func markAsSeen(_ url: String) {
        seenURLs.insert(url)
    }

    // MARK: - Logique de détection

    /// Vérifie si le clipboard contient une nouvelle URL.
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general

        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let content = pasteboard.string(forType: .string) else { return }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else {
            return
        }

        guard !seenURLs.contains(trimmed) else { return }

        seenURLs.insert(trimmed)
        withAnimation {
            detectedURL = trimmed
        }
    }
}
