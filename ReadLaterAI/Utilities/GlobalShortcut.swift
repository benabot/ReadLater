import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - ShortcutKey

struct ShortcutKey: Codable, Equatable, Hashable, Sendable {
    let keyCode: UInt16
    let modifiers: UInt

    static let defaultShortcut = ShortcutKey(
        keyCode: UInt16(kVK_ANSI_R),
        modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue
    )

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

    /// Identifiant unique pour Picker
    var id: String { "\(keyCode)-\(modifiers)" }

    private var keyName: String {
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
        case kVK_Space: String(localized: "Space")
        default: "?\(keyCode)"
        }
    }
}

// MARK: - ShortcutRecordingState

@MainActor
final class ShortcutRecordingState {
    static let shared = ShortcutRecordingState()
    var isRecording = false
    private init() {}
}

// MARK: - Predefined Shortcuts
// Liste de raccourcis prédéfinis que l'utilisateur peut choisir dans un menu.
// C'est plus fiable qu'un recorder custom car aucun monitor NSEvent n'est
// nécessaire, ce qui évite les conflits avec l'AppDelegate.

enum PredefinedShortcuts {
    static let all: [ShortcutKey] = [
        // ⌥⌘ + lettre
        ShortcutKey(keyCode: UInt16(kVK_ANSI_R), modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_L), modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_B), modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_S), modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_K), modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue),
        // ⌃⌥ + lettre
        ShortcutKey(keyCode: UInt16(kVK_ANSI_R), modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_L), modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_B), modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue),
        // ⇧⌘ + lettre
        ShortcutKey(keyCode: UInt16(kVK_ANSI_R), modifiers: NSEvent.ModifierFlags([.shift, .command]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_L), modifiers: NSEvent.ModifierFlags([.shift, .command]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_B), modifiers: NSEvent.ModifierFlags([.shift, .command]).rawValue),
        // ⌃⇧ + lettre
        ShortcutKey(keyCode: UInt16(kVK_ANSI_R), modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_L), modifiers: NSEvent.ModifierFlags([.control, .shift]).rawValue),
        // ⌃⌘ + lettre
        ShortcutKey(keyCode: UInt16(kVK_ANSI_R), modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue),
        ShortcutKey(keyCode: UInt16(kVK_ANSI_L), modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue),
    ]
}

// MARK: - ShortcutRecorderView (Picker-based)
// Au lieu d'un recorder qui capture les touches (source de bugs avec NSPopover),
// on utilise un simple menu déroulant avec des raccourcis prédéfinis.
// C'est le pattern utilisé par CleanShot, Paste, Spark, etc.

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutKey

    var body: some View {
        HStack(spacing: 8) {
            // Menu déroulant avec les raccourcis disponibles.
            // Picker en SwiftUI = <select> en HTML.
            Picker("", selection: $shortcut) {
                ForEach(PredefinedShortcuts.all, id: \.id) { preset in
                    Text(preset.displayString)
                        .font(.system(.body, design: .monospaced))
                        .tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(minWidth: 130)

            // Bouton reset
            Button {
                shortcut = .defaultShortcut
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reset to default (⌥⌘R)")
        }
    }
}
