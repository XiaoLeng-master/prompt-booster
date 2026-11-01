import Cocoa
import Carbon.HIToolbox
import Foundation
import ServiceManagement

// ============================================================
// PromptBooster (macOS)
// 通用大模型提示词增强：选中文字 → 快捷键 → 原地增强
//
// 配置：优先读环境变量，其次读 ~/.prompt-booster/config.json
// 所有密钥均不在代码中，仓库不含任何真实密钥。
// ============================================================

// MARK: - 配置（默认值，会被环境变量 / 配置文件覆盖）

// 默认模型（无配置时兜底，需配 key 才能用）
let DEFAULT_MODEL = "deepseek-chat"

// MARK: - 通用大模型平台接入层

// 平台定义：name=显示名，baseURL=chat/completions 端点前缀，envKey=对应的环境变量名
struct LLMProvider {
    let name: String
    let baseURL: String
    let envKey: String
}

// 内置平台表（可自行增删）。baseURL 均为「原生 OpenAI 兼容」chat/completions 路径。
// 请求时统一追加 "/chat/completions"。
let LLM_PROVIDERS: [String: LLMProvider] = [
    "deepseek": LLMProvider(name: "DeepSeek", baseURL: "https://api.deepseek.com/v1", envKey: "DEEPSEEK_API_KEY"),
    "zhipu":    LLMProvider(name: "智谱 GLM", baseURL: "https://open.bigmodel.cn/api/paas/v4", envKey: "ZHIPU_API_KEY"),
    "qwen":     LLMProvider(name: "通义千问", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", envKey: "QWEN_API_KEY"),
    "moonshot": LLMProvider(name: "Kimi", baseURL: "https://api.moonshot.cn/v1", envKey: "MOONSHOT_API_KEY"),
    "doubao":   LLMProvider(name: "豆包", baseURL: "https://ark.cn-beijing.volces.com/api/v3", envKey: "DOUBAO_API_KEY"),
]

// 运行时配置
struct AppConfig {
    var providerKey: String      // 平台 id，如 "deepseek"
    var model: String
    var apiKey: String
    var baseURL: String
}

func loadConfig() -> AppConfig {
    let env = ProcessInfo.processInfo.environment

    // 1) 环境变量优先：PB_PROVIDER / PB_MODEL / <平台>_API_KEY
    let providerId = env["PB_PROVIDER"] ?? "deepseek"
    let model = env["PB_MODEL"] ?? DEFAULT_MODEL
    var apiKey = env[LLM_PROVIDERS[providerId]?.envKey ?? "DEEPSEEK_API_KEY"] ?? ""

    // 2) 回退到配置文件 ~/.prompt-booster/config.json
    if apiKey.isEmpty {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let cfgURL = home.appendingPathComponent(".prompt-booster/config.json")
        if let data = try? Data(contentsOf: cfgURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let v = obj["provider"] as? String { _ = v }
            if let v = obj["model"] as? String, !v.isEmpty { _ = v }
            if let v = obj["api_key"] as? String, !v.isEmpty { apiKey = v }
        }
    }

    let provider = LLM_PROVIDERS[providerId] ?? LLM_PROVIDERS["deepseek"]!
    return AppConfig(providerKey: providerId,
                     model: model,
                     apiKey: apiKey,
                     baseURL: provider.baseURL)
}

// MARK: - 提示词（通用提示词增强，不绑定任何平台）

let SYSTEM_PROMPT = """
You are a Prompt Engineering Expert specializing in improving user prompts. When given a prompt, analyze and enhance it to create a more effective version while maintaining its core purpose.

TASK: analyze and enhance the prompt to create a more effective version while maintaining its core purpose.

Apply prompt engineering principles: write clear specific instructions, include necessary context, set explicit parameters and constraints, structure the output format, add relevant examples, match tone and complexity, remove redundant information. Maintain the original goal. Do NOT request guides/how-tos unless asked. Do NOT ask for code snippets. Do NOT suggest specific technologies unless mentioned. Do NOT explain HOW, focus on WHAT. Do NOT answer questions - expand/rewrite them to be more detailed.

IMPORTANT CONSTRAINTS:
1. Language matching is the highest priority - respond strictly in the same language as the input.
2. Keep the enhanced prompt concise - around 800 characters max.

FORMAT: Provide only the enhanced prompt with no additional commentary.
"""

func userTemplate(_ input: String) -> String {
    return """
You are a prompt enhancement assistant. Improve the user prompt while preserving its intent and language.

USER INPUT:
\(input)

TASK: Rewrite the user input into a clearer, more specific prompt for the target AI assistant.

CRITICAL PRIORITY - LANGUAGE CONSISTENCY:
Respond in the exact same language as the input. Never include language analysis or labels in the output.

ENHANCEMENT REQUIREMENTS:
1. Return only the enhanced prompt text; no explanations, prefaces, markdown fences, or labels.
2. Preserve original intent, topic, constraints, and target output type. Do not answer the request.
3. Always make a substantive enhancement when possible.
4. If already clear, lightly polish instead of returning unchanged.
5. Keep complete and concise; do not end with unfinished list or trailing colon.
6. Do not add unrelated requirements or unsupported facts.
"""
}

// MARK: - 文件日志（排障用，写入 ~/.prompt-booster/booster.log）
func log(_ msg: String) {
    let line = "\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)) \(msg)\n"
    if let data = line.data(using: .utf8) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".prompt-booster/booster.log")
        if let fh = FileHandle(forWritingAtPath: url.path) {
            fh.seekToEndOfFile()
            fh.write(data)
            try? fh.close()
        } else {
            try? data.write(to: url)
        }
    }
    NSLog("[PromptBooster] %@", msg)
}

// MARK: - 全局快捷键回调
var hotKeyRef: EventHotKeyRef?
var hotKeySequence: UInt32 = 0

func installHotKeyHandler() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        log("快捷键已触发")
        enhanceSelectedText()
        return noErr
    }, 1, &eventType, nil, nil)
}

func registerHotKey(_ shortcut: Shortcut) -> Bool {
    hotKeySequence += 1
    let hotKeyID = EventHotKeyID(signature: OSType(0x50424F53), id: hotKeySequence)
    var newRef: EventHotKeyRef?
    let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID,
                                     GetApplicationEventTarget(), 0, &newRef)
    guard status == noErr, let newRef else {
        log("!! 快捷键注册失败，OSStatus=\(status)（\(shortcut.title)）")
        return false
    }
    if let oldRef = hotKeyRef { UnregisterEventHotKey(oldRef) }
    hotKeyRef = newRef
    log("快捷键注册成功（\(shortcut.title)）")
    return true
}

// MARK: - 读取选中文本

// 方案 A（首选）：通过 Accessibility API 直接读选中文本，不经过剪贴板，
// 不受 macOS 剪贴板隐私机制影响，也不依赖目标 App 响应模拟按键。
func readSelectedTextViaAX() -> String? {
    let sysWide = AXUIElementCreateSystemWide()
    var focused: CFTypeRef?
    guard AXUIElementCopyAttributeValue(sysWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
          let el = focused else {
        log("AX：无法获取焦点元素")
        return nil
    }
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(el as! AXUIElement,
                                               kAXSelectedTextAttribute as CFString, &value)
    guard result == .success, let text = value as? String, !text.isEmpty else {
        log("AX：焦点元素不提供选中文本（AXError=\(result.rawValue)）")
        return nil
    }
    return text
}

// 方案 B（兜底）：模拟 Cmd+C + 轮询剪贴板。
func readSelectedTextViaClipboard() -> String {
    let pb = NSPasteboard.general
    let countBefore = pb.changeCount
    pb.clearContents()
    let src = CGEventSource(stateID: .combinedSessionState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: true) // C
    down?.flags = .maskCommand
    let up = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: false)
    up?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
    // 轮询等待目标 App 完成复制（clear 占用一次 changeCount，复制再加一次），最多等 1 秒
    let deadline = Date().addingTimeInterval(1.0)
    while Date() < deadline {
        if pb.changeCount >= countBefore + 2 { break }
        usleep(50_000)
    }
    let text = pb.string(forType: .string) ?? ""
    if text.isEmpty {
        log("剪贴板兜底：Cmd+C 后无内容（前台=\(frontmostAppName())，changeCount 增量=\(pb.changeCount - countBefore)）")
    }
    return text
}

func frontmostAppName() -> String {
    NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知"
}

// MARK: - 原地替换（模拟 Cmd+V）
func pasteText(_ text: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
    usleep(80_000)
    let src = CGEventSource(stateID: .combinedSessionState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true) // V
    down?.flags = .maskCommand
    let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
    up?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

// MARK: - 调通用 LLM API（OpenAI 兼容 chat/completions）
func enhance(_ text: String, completion: @escaping (String?) -> Void) {
    let cfg = loadConfig()
    guard !cfg.apiKey.isEmpty else {
        NSLog("[PromptBooster] 未配置 API Key，请在 ~/.prompt-booster/config.json 或环境变量中设置")
        completion(nil)
        return
    }
    let url = URL(string: cfg.baseURL + "/chat/completions")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.timeoutInterval = 60
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("Bearer \(cfg.apiKey)", forHTTPHeaderField: "Authorization")

    let body: [String: Any] = [
        "model": cfg.model,
        "temperature": 0.3,
        "messages": [
            ["role": "system", "content": SYSTEM_PROMPT],
            ["role": "user", "content": userTemplate(text)],
        ],
    ]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let task = URLSession.shared.dataTask(with: req) { data, _, _ in
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            NSLog("[PromptBooster] 请求失败：%@", String(data: data ?? Data(), encoding: .utf8) ?? "")
            completion(nil)
            return
        }
        completion(content)
    }
    task.resume()
}

// MARK: - 主流程
func enhanceSelectedText() {
    log("触发，前台应用：\(frontmostAppName())")
    // 首选 AX 直读；失败则退回 Cmd+C 剪贴板方案
    let textViaAX = readSelectedTextViaAX()
    var raw = ""
    var source = "无"
    if let axText = textViaAX {
        raw = axText
        source = "AX直读"
    } else {
        let clipText = readSelectedTextViaClipboard()
        if !clipText.isEmpty {
            raw = clipText
            source = "剪贴板兜底"
        }
    }
    log("读选区完成，长度=\(raw.count)，来源=\(source)")
    let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !original.isEmpty else {
        log("!! 选区为空（未选中文字，或当前应用不支持读取选区）")
        return
    }

    enhance(original) { result in
        guard let result = result else {
            log("!! API 调用失败或返回为空")
            return
        }
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
        if !cleaned.isEmpty {
            pasteText(cleaned)
            log("原地替换完成，长度=\(cleaned.count)")
        }
    }
}

// MARK: - 菜单栏与首次启动
final class ShortcutRecorder: NSView {
    var shortcut: Shortcut
    private let label: NSTextField

    init(shortcut: Shortcut) {
        self.shortcut = shortcut
        label = NSTextField(labelWithString: "快捷键：\(shortcut.title)（点击这里后按新组合）")
        super.init(frame: NSRect(x: 0, y: 0, width: 350, height: 36))
        label.frame = bounds.insetBy(dx: 8, dy: 8)
        addSubview(label)
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.cornerRadius = 5
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if let candidate = Shortcut.validated(keyCode: UInt32(event.keyCode), modifiers: modifiers,
                                               key: event.charactersIgnoringModifiers ?? "") {
            shortcut = candidate
            label.stringValue = "快捷键：\(candidate.title)"
        } else {
            NSSound.beep()
        }
    }
}

final class AppController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let shortcutItem = NSMenuItem()
    private let loginItem = NSMenuItem()
    private var shortcut = ShortcutSettings.load()

    func start() {
        statusItem.button?.title = "✦"
        shortcutItem.target = self
        shortcutItem.action = #selector(changeShortcut)
        menu.addItem(shortcutItem)
        loginItem.target = self
        loginItem.action = #selector(toggleLogin)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 PromptBooster", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        menu.delegate = self
        statusItem.menu = menu
        refreshMenu()
        installHotKeyHandler()

        DispatchQueue.main.async {
            if !UserDefaults.standard.bool(forKey: "onboardingCompleted") { self.showOnboarding() }
            self.startAccessibility()
        }
    }

    private func refreshMenu() {
        shortcutItem.title = "快捷键：\(shortcut.title)…"
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            loginItem.title = status == .requiresApproval ? "登录时自动启动（待系统批准）" : "登录时自动启动"
            loginItem.state = status == .enabled ? .on : .off
        } else {
            loginItem.title = "登录时自动启动（在系统设置中操作）"
            loginItem.state = .off
        }
    }

    func menuWillOpen(_ menu: NSMenu) { refreshMenu() }

    private func showOnboarding() {
        let alert = NSAlert()
        alert.messageText = "欢迎使用 PromptBooster"
        alert.informativeText = "选中文字后按快捷键增强提示词。只有按下快捷键时，文字才会发送到你配置的模型服务。"
        alert.addButton(withTitle: "保存设置")
        alert.addButton(withTitle: "稍后设置")
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 100))
        let recorder = ShortcutRecorder(shortcut: shortcut)
        recorder.frame.origin.y = 62
        accessory.addSubview(recorder)
        let login = NSButton(checkboxWithTitle: "登录时自动启动", target: nil, action: nil)
        login.frame = NSRect(x: 0, y: 31, width: 350, height: 25)
        accessory.addSubview(login)
        let hint = NSTextField(labelWithString: "可随时从菜单栏 ✦ 修改；系统权限仍由 macOS 管理。")
        hint.frame = NSRect(x: 0, y: 0, width: 350, height: 25)
        accessory.addSubview(hint)
        alert.accessoryView = accessory
        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeFirstResponder(recorder)
        if alert.runModal() == .alertFirstButtonReturn {
            applyShortcut(recorder.shortcut)
            if login.state == .on { enableLogin() }
        }
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
    }

    @objc private func changeShortcut() {
        let alert = NSAlert()
        alert.messageText = "选择快捷键"
        alert.informativeText = "点击输入框后按新的组合键（至少两个修饰键，且包含 ⌘、⌃ 或 ⌥）。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let recorder = ShortcutRecorder(shortcut: shortcut)
        alert.accessoryView = recorder
        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeFirstResponder(recorder)
        if alert.runModal() == .alertFirstButtonReturn { applyShortcut(recorder.shortcut) }
    }

    private func applyShortcut(_ candidate: Shortcut) {
        if candidate == shortcut { return }
        if AXIsProcessTrusted() && !registerHotKey(candidate) {
            showMessage("快捷键不可用", "\(candidate.title) 可能已被其他程序占用，请换一个组合。原快捷键仍然有效。")
            return
        }
        shortcut = candidate
        ShortcutSettings.save(candidate)
        refreshMenu()
    }

    @objc private func toggleLogin() {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                do { try SMAppService.mainApp.unregister() }
                catch { showMessage("无法关闭自动启动", error.localizedDescription) }
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                enableLogin()
            }
        } else {
            showMessage("请在系统设置中添加", "系统设置 → 通用 → 登录项与扩展 → 登录时打开 → 添加 PromptBooster.app。")
        }
        refreshMenu()
    }

    private func enableLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
                if SMAppService.mainApp.status == .requiresApproval {
                    showMessage("需要系统批准", "请在系统设置 → 通用 → 登录项与扩展中允许 PromptBooster。")
                    SMAppService.openSystemSettingsLoginItems()
                }
            } catch {
                showMessage("无法启用自动启动", error.localizedDescription)
            }
        } else {
            showMessage("请在系统设置中添加", "macOS 12 请到系统设置 → 用户与群组 → 登录项中添加 PromptBooster.app。")
        }
        refreshMenu()
    }

    private func startAccessibility() {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(prompt) {
            log("启动：辅助功能已授权")
            if !registerHotKey(shortcut) { showMessage("快捷键不可用", "请从菜单栏 ✦ 更换快捷键。") }
        } else {
            log("启动：辅助功能未授权，等待用户授权")
            DispatchQueue.global().async {
                while !AXIsProcessTrusted() { usleep(1_000_000) }
                DispatchQueue.main.async {
                    log("辅助功能授权成功")
                    if !registerHotKey(self.shortcut) { self.showMessage("快捷键不可用", "请从菜单栏 ✦ 更换快捷键。") }
                }
            }
        }
    }

    private func showMessage(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--unregister-login") {
    if #available(macOS 13.0, *) {
        if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
            do { try SMAppService.mainApp.unregister() }
            catch {
                fputs("无法注销登录项：\(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
    }
    exit(0)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController()
controller.start()
app.run()
