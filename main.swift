import Cocoa
import Carbon.HIToolbox
import Foundation

// ============================================================
// PromptBooster (macOS)
// 通用大模型提示词增强：选中文字 → 快捷键 → 原地增强
//
// 配置：优先读环境变量，其次读 ~/.prompt-booster/config.json
// 所有密钥均不在代码中，仓库不含任何真实密钥。
// ============================================================

// MARK: - 配置（默认值，会被环境变量 / 配置文件覆盖）

// 全局快捷键：⌘⇧E。修改方式见 README「快捷键」章节，或改下面两个常量后重新编译。
let HOTKEY_KEYCODE: UInt32 = 14 // E 键
let HOTKEY_MODIFIERS: UInt32 = UInt32(cmdKey | shiftKey)

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

// MARK: - 全局快捷键回调
var hotKeyRef: EventHotKeyRef?

func registerHotKey() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        enhanceSelectedText()
        return noErr
    }, 1, &eventType, nil, nil)

    let hotKeyID = EventHotKeyID(signature: OSType(0x50424F53), id: 1) // 'PBOS'
    RegisterEventHotKey(HOTKEY_KEYCODE, HOTKEY_MODIFIERS, hotKeyID,
                        GetApplicationEventTarget(), 0, &hotKeyRef)
}

// MARK: - 读取当前选中文本（模拟 Cmd+C）
func readSelectedText() -> String {
    let pb = NSPasteboard.general
    pb.clearContents()
    let src = CGEventSource(stateID: .combinedSessionState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: true) // C
    down?.flags = .maskCommand
    let up = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: false)
    up?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
    usleep(200_000)
    return pb.string(forType: .string) ?? ""
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
    let original = readSelectedText().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !original.isEmpty else { return }

    enhance(original) { result in
        guard let result = result else { return }
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
        if !cleaned.isEmpty {
            pasteText(cleaned)
        }
    }
}

// MARK: - 入口
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
registerHotKey()
print("PromptBooster 已启动，快捷键 ⌘⇧E")
app.run()
