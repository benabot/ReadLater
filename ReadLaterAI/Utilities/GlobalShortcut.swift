import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - ShortcutKey
// Représente un raccourci clavier personnalisable, stocké dans UserDefaults.
// On sérialise le keyCode + les modifiers comme deux entiers.

struct ShortcutKey: Codable, Equatable, Sendable {
    let keyCode: UInt16
    let modifiers: UInt  // NSEvent.ModifierFlags.rawValue

    /// Le raccourci par défaut : ⌥⌘R
    static let defaultShortcut = ShortcutKey(
        keyCode: UInt16(kVK_ANSI_R),
        modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue
    )

    /// Affichage lisible du raccourci (ex: "⌥⌘R")
    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined()
    }

    /// Nom lisible de la touche
    private var keyName: String {
        // Mapper les keyCodes courants vers des noms lisibles.
        // Les keyCodes sont hérités de l'API Carbon (layout QWERTY).
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_Space: String(localized: "Space")
        case kVK_Return: "↩"
        case kVK_Tab: "⇥"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        default: "?\(keyCode)"
        }
    }
}

// MARK: - ShortcutRecorderView
// Vue SwiftUI qui permet d'enregistrer un nouveau raccourci clavier.
// L'utilisateur clique sur le champ, puis appuie sur la combinaison souhaitée.
// C'est comme les "hotkey recorders" dans Alfred, Raycast, etc.

// MARK: - ShortcutRecordingState
// Flag global partagé entre le ShortcutRecorderView et l'AppDelegate.
// Quand isRecording = true, l'AppDelegate ignore les raccourcis clavier
// pour ne pas interférer avec l'enregistrement d'un nouveau raccourci.
//
// @MainActor car il est lu/écrit uniquement depuis le main thread (UI).
// C'est l'équivalent d'une variable globale réactive en Vue (un petit store).

@MainActor
final class ShortcutRecordingState {
    static let shared = ShortcutRecordingState()
    var isRecording = false
    private init() {}
}

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutKey
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            // Zone d'affichage / enregistrement du raccourci
            Text(isRecording ? String(localized: "Press a shortcut…") : shortcut.displayString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isRecording ? .orange : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 120)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.orange.opacity(0.1) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.orange : Color.primary.opacity(0.2), lineWidth: 1)
                )
                .onTapGesture {
                    startRecording()
                }

            if isRecording {
                Button("Cancel") {
                    stopRecording()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }

            Button {
                shortcut = .defaultShortcut
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Réinitialiser au raccourci par défaut (⌥⌘R)")
        }
    }

    private func startRecording() {
        isRecording = true
        ShortcutRecordingState.shared.isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Ignorer les touches sans modificateur (sauf les touches F)
            let isFKey = (kVK_F1...kVK_F8).contains(Int(event.keyCode))
            guard !modifiers.isEmpty || isFKey else {
                return event
            }

            // Ignorer si seuls les modificateurs sont pressés (pas de lettre)
            let modOnlyKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modOnlyKeys.contains(event.keyCode) else {
                return event
            }

            shortcut = ShortcutKey(
                keyCode: event.keyCode,
                modifiers: modifiers.rawValue
            )
            stopRecording()
            return nil  // Consommer l'événement
        }
    }

    private func stopRecording() {
        isRecording = false
        ShortcutRecordingState.shared.isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
