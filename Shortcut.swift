import Carbon.HIToolbox
import Foundation

struct Shortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let key: String

    static let `default` = Shortcut(keyCode: 14, modifiers: UInt32(cmdKey | shiftKey), key: "E")

    static func validated(keyCode: UInt32, modifiers: UInt32, key: String) -> Shortcut? {
        let allowed = UInt32(cmdKey | shiftKey | optionKey | controlKey)
        let primary = UInt32(cmdKey | optionKey | controlKey)
        let normalized = key.uppercased()
        guard keyCode <= 127,
              modifiers & ~allowed == 0,
              modifiers & primary != 0,
              modifiers.nonzeroBitCount >= 2,
              normalized.count == 1,
              normalized.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").contains($0) }) else {
            return nil
        }
        return Shortcut(keyCode: keyCode, modifiers: modifiers, key: normalized)
    }

    var title: String {
        let symbols = [(UInt32(controlKey), "⌃"), (UInt32(optionKey), "⌥"),
                       (UInt32(shiftKey), "⇧"), (UInt32(cmdKey), "⌘")]
        return symbols.filter { modifiers & $0.0 != 0 }.map(\.1).joined() + key
    }
}

enum ShortcutSettings {
    private static let storageKey = "shortcut"

    static func load(from defaults: UserDefaults = .standard) -> Shortcut {
        guard let value = defaults.dictionary(forKey: storageKey),
              let code = value["keyCode"] as? Int,
              let modifiers = value["modifiers"] as? Int,
              let key = value["key"] as? String,
              (0...127).contains(code), (0...Int(UInt32.max)).contains(modifiers),
              let shortcut = Shortcut.validated(keyCode: UInt32(code), modifiers: UInt32(modifiers), key: key) else {
            return .default
        }
        return shortcut
    }

    static func save(_ shortcut: Shortcut, to defaults: UserDefaults = .standard) {
        defaults.set(["keyCode": Int(shortcut.keyCode), "modifiers": Int(shortcut.modifiers), "key": shortcut.key], forKey: storageKey)
    }
}
