import AppKit
import Carbon

// MARK: - ShortcutKey

struct ShortcutKey {
    static let displayString = "⌃⌥⌘M"
    static let keyCode: UInt32 = 41  // kVK_ANSI_Semicolon (physical position = M on AZERTY)
    static let carbonModifiers: UInt32 = UInt32(cmdKey | optionKey | controlKey)
}

// MARK: - CarbonHotKeyManager

@MainActor
final class CarbonHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    var onTriggered: (@MainActor () -> Void)?

    func register() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            readLaterHotKeyHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(
            signature: readLaterHotkeySignature,
            id: 1
        )

        RegisterEventHotKey(
            ShortcutKey.keyCode,
            ShortcutKey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func handleHotKeyEvent() {
        onTriggered?()
    }
}

// MARK: - Carbon C callback

private let readLaterHotkeySignature: OSType = fourCharCode("RLAI")

private let readLaterHotKeyHandler: EventHandlerUPP = { _, eventRef, userData in
    guard let eventRef, let userData else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr, hotKeyID.id == 1 else { return noErr }

    let manager = Unmanaged<CarbonHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

    Task { @MainActor in
        manager.handleHotKeyEvent()
    }

    return noErr
}

private func fourCharCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}
