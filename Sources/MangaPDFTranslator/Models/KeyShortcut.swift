import AppKit

/// A user-recorded keyboard shortcut: a base key plus modifier flags. Captured
/// by typing in the settings recorder rather than chosen from a preset list.
struct KeyShortcut: Equatable, Codable {
    /// `charactersIgnoringModifiers`, lowercased (e.g. "t", " ", "\r").
    var key: String
    /// Masked `NSEvent.ModifierFlags` raw value (command/option/control/shift).
    var modifiers: UInt

    static let translateDefault = KeyShortcut(key: "t", modifiers: NSEvent.ModifierFlags.command.rawValue)
    static let removeNewlinesDefault = KeyShortcut(key: "j", modifiers: NSEvent.ModifierFlags.command.rawValue)

    private static let trackedFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var isEmpty: Bool { key.isEmpty }

    private var modifierFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    func matches(_ event: NSEvent) -> Bool {
        guard !key.isEmpty else { return false }
        let mods = event.modifierFlags.intersection(Self.trackedFlags)
        guard mods.rawValue == modifiers else { return false }
        return (event.charactersIgnoringModifiers ?? "").lowercased() == key
    }

    static func from(_ event: NSEvent) -> KeyShortcut? {
        let key = (event.charactersIgnoringModifiers ?? "").lowercased()
        guard !key.isEmpty else { return nil }
        let mods = event.modifierFlags.intersection(trackedFlags).rawValue
        return KeyShortcut(key: key, modifiers: mods)
    }

    var displayString: String {
        guard !key.isEmpty else { return "" }
        var result = ""
        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }
        result += keyLabel
        return result
    }

    private var keyLabel: String {
        switch key {
        case " ": return "Space"
        case "\r", "\u{3}": return "↩"
        case "\t": return "⇥"
        case "\u{7f}", "\u{8}": return "⌫"
        default: return key.uppercased()
        }
    }

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decoded(_ string: String?) -> KeyShortcut? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(KeyShortcut.self, from: data)
    }
}
