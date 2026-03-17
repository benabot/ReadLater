import AppKit
import SwiftUI
import Carbon.HIToolbox

// MARK: - ShortcutKey

struct ShortcutKey: Codable, Equatable, Sendable {
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

// MARK: - ShortcutRecordingState
// Flag global pour que l'AppDelegate sache quand ignorer les raccourcis.

@MainActor
final class ShortcutRecordingState {
    static let shared = ShortcutRecordingState()
    var isRecording = false
    private init() {}
}

// MARK: - KeyCaptureView (NSViewRepresentable)
// Une NSView custom qui capture les keyDown quand elle a le focus.
// Contrairement aux NSEvent monitors (qui interceptent TOUS les événements
// de l'app), cette NSView ne capture que les touches quand elle est "first
// responder" (= quand elle a le focus clavier).
//
// C'est l'approche la plus propre car :
// 1. Pas de conflit avec les monitors de l'AppDelegate
// 2. L'événement est consommé par la vue avant d'arriver aux monitors
// 3. Pas besoin de flag de synchronisation complexe
//
// NSViewRepresentable est le pont pour utiliser une NSView AppKit dans SwiftUI.
// C'est comme un wrapper de composant natif (Web Component en JS).

struct KeyCaptureView: NSViewRepresentable {
    var onKeyDown: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }

    // La NSView custom qui devient first responder et capte les touches.
    class KeyCaptureNSView: NSView {
        var onKeyDown: ((UInt16, NSEvent.ModifierFlags) -> Void)?

        // acceptsFirstResponder = cette vue PEUT recevoir le focus clavier.
        // Par défaut, les NSView ne l'acceptent pas.
        override var acceptsFirstResponder: Bool { true }

        // Quand la vue apparaît, on prend le focus automatiquement.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        // Intercepte les touches et les passe au callback.
        // L'événement est "consommé" ici — il ne remonte PAS aux monitors.
        override func keyDown(with event: NSEvent) {
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Ignorer les touches modificateurs seules (Cmd, Alt, etc. sans lettre)
            let modOnlyKeys: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modOnlyKeys.contains(event.keyCode) else { return }

            // Ignorer les touches sans modificateur (sauf F-keys)
            let isFKey = (kVK_F1...kVK_F8).contains(Int(event.keyCode))
            guard !modifiers.isEmpty || isFKey else { return }

            onKeyDown?(event.keyCode, modifiers)
        }
    }
}

// MARK: - ShortcutRecorderView

struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutKey
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                // Mode enregistrement : affiche la NSView de capture
                ZStack {
                    // La KeyCaptureView invisible qui capture les touches
                    KeyCaptureView { keyCode, modifiers in
                        shortcut = ShortcutKey(keyCode: keyCode, modifiers: modifiers.rawValue)
                        stopRecording()
                    }
                    .frame(width: 0, height: 0)
                    .opacity(0)

                    Text("Press a shortcut…")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(minWidth: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                }

                Button("Cancel") {
                    stopRecording()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            } else {
                // Mode affichage : montre le raccourci actuel
                Text(shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(minWidth: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .onTapGesture {
                        startRecording()
                    }
            }

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

    private func startRecording() {
        ShortcutRecordingState.shared.isRecording = true
        isRecording = true
    }

    private func stopRecording() {
        isRecording = false
        // Petit délai avant de réactiver les monitors de l'AppDelegate.
        // Ça laisse le temps au UserDefaults de se mettre à jour sans
        // que le nouveau raccourci ne trigger immédiatement un toggle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            ShortcutRecordingState.shared.isRecording = false
        }
    }
}
