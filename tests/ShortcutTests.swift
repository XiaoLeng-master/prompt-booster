import Carbon.HIToolbox
import Foundation

@main
struct ShortcutTests {
    static func main() {
        let suite = "PromptBooster.ShortcutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        assert(ShortcutSettings.load(from: defaults) == .default)
        let chosen = Shortcut.validated(keyCode: 40, modifiers: UInt32(cmdKey | optionKey), key: "k")!
        assert(chosen.title == "⌥⌘K")
        ShortcutSettings.save(chosen, to: defaults)
        assert(ShortcutSettings.load(from: defaults) == chosen)

        assert(Shortcut.validated(keyCode: 40, modifiers: UInt32(shiftKey), key: "K") == nil)
        assert(Shortcut.validated(keyCode: 40, modifiers: UInt32(cmdKey), key: "K") == nil)
        assert(Shortcut.validated(keyCode: 40, modifiers: UInt32(cmdKey), key: "⌘") == nil)
        assert(Shortcut.validated(keyCode: 200, modifiers: UInt32(cmdKey), key: "K") == nil)
        defaults.set(["keyCode": 200, "modifiers": Int(cmdKey), "key": "K"], forKey: "shortcut")
        assert(ShortcutSettings.load(from: defaults) == .default)
        defaults.set(["keyCode": Int(UInt32.max) + 1, "modifiers": Int(cmdKey), "key": "K"], forKey: "shortcut")
        assert(ShortcutSettings.load(from: defaults) == .default)
        print("ShortcutTests passed")
    }
}
