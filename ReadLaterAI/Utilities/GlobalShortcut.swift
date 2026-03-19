import AppKit
import Carbon.HIToolbox

// MARK: - ShortcutKey
// Configuration centralisée du raccourci global.
// Le raccourci utilise keyCode 41 (position physique QWERTY ";" / AZERTY "M").
// Sur clavier AZERTY : ⌃⌥⌘M
// Sur clavier QWERTY : ⌃⌥⌘;

struct ShortcutKey {
    // Affichage adapté au clavier AZERTY
    static let displayString = "⌃⌥⌘M"

    // kVK_ANSI_Semicolon = 41 (position physique, pas le caractère)
    static let keyCode: UInt16 = 41
    static let modifiers: NSEvent.ModifierFlags = [.control, .option, .command]
}
