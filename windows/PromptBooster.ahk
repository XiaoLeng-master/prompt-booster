; ============================================================
; PromptBooster for Windows  (AutoHotkey v2)
; 通用大模型提示词增强：选中文字 → Ctrl+Shift+E → 原地增强
; 配置：优先环境变量，其次 %USERPROFILE%\.prompt-booster\config.json
; 代码不含任何真实密钥。
; ============================================================
#Requires AutoHotkey v2.0

; ---------- 默认快捷键（可改：^=Ctrl  +=Shift  !=Alt  #=Win）----------
HOTKEY := "^+e"

; ---------- 默认模型（无配置时兜底，需配 key 才能用）----------
DEFAULT_MODEL := "deepseek-chat"

; ---------- 通用大模型平台表：name -> baseURL（OpenAI 兼容 chat/completions）----------
Providers := Map(
    "deepseek", Map("name", "DeepSeek", "baseURL", "https://api.deepseek.com/v1", "envKey", "DEEPSEEK_API_KEY"),
    "zhipu",    Map("name", "智谱 GLM", "baseURL", "https://open.bigmodel.cn/api/paas/v4", "envKey", "ZHIPU_API_KEY"),
    "qwen",     Map("name", "通义千问", "baseURL", "https://dashscope.aliyuncs.com/compatible-mode/v1", "envKey", "QWEN_API_KEY"),
    "moonshot", Map("name", "Kimi", "baseURL", "https://api.moonshot.cn/v1", "envKey", "MOONSHOT_API_KEY"),
    "doubao",   Map("name", "豆包", "baseURL", "https://ark.cn-beijing.volces.com/api/v3", "envKey", "DOUBAO_API_KEY"),
)

; ---------- 读取配置：环境变量 > 配置文件 ----------
LoadConfig() {
    provider := EnvGet("PB_PROVIDER")
    if (provider = "")
        provider := "deepseek"
    model := EnvGet("PB_MODEL")
    if (model = "")
        model := DEFAULT_MODEL

    p := Providers.Has(provider) ? Providers[provider] : Providers["deepseek"]
    apiKey := EnvGet(p["envKey"])
    if (apiKey = "")
        apiKey := EnvGet("DEEPSEEK_API_KEY")

    ; 回退到配置文件 %USERPROFILE%\.prompt-booster\config.json
    if (apiKey = "") {
        cfgPath := A_MyDocuments "\..\.prompt-booster\config.json"
        cfgPath := EnvGet("USERPROFILE") "\.prompt-booster\config.json"
        if FileExist(cfgPath) {
            raw := FileRead(cfgPath)
            ; 极简提取 "api_key":"..." / "model":"..." / "provider":"..."
            if RegExMatch(raw, '"api_key"\s*:\s*"([^"]*)"', &m)
                apiKey := m[1]
            if RegExMatch(raw, '"model"\s*:\s*"([^"]*)"', &m)
                model := m[1]
            if RegExMatch(raw, '"provider"\s*:\s*"([^"]*)"', &m) && Providers.Has(m[1])
                p := Providers[m[1]]
        }
    }
    return Map("provider", p, "model", model, "apiKey", apiKey)
}

; ---------- 提示词（通用，不绑定平台）----------
SYSTEM_PROMPT := "
(
You are a Prompt Engineering Expert specializing in improving user prompts. When given a prompt, analyze and enhance it to create a more effective version while maintaining its core purpose.

Apply prompt engineering principles: write clear specific instructions, include necessary context, set explicit parameters, structure output format, add examples, match tone, remove redundancy. Maintain the original goal. Do NOT request guides/how-tos unless asked. Do NOT ask for code snippets. Do NOT suggest specific technologies unless mentioned. Do NOT explain HOW, focus on WHAT. Do NOT answer questions - expand/rewrite them.

IMPORTANT CONSTRAINTS:
1. Language matching is highest priority - respond strictly in the same language as the input.
2. Keep concise - around 800 characters max.

FORMAT: Provide only the enhanced prompt with no additional commentary.
)"

UserTemplate(input) {
    return "
(
You are a prompt enhancement assistant. Improve the user prompt while preserving its intent and language.

USER INPUT:
" input "

TASK: Rewrite the user input into a clearer, more specific prompt.

CRITICAL PRIORITY - LANGUAGE CONSISTENCY: respond in the exact same language as the input. Never include language labels in the output.

REQUIREMENTS:
1. Return only the enhanced prompt text; no explanations or fences.
2. Preserve original intent, topic, constraints. Do not answer the request.
3. Make a substantive enhancement when possible; if already clear, lightly polish.
4. Keep complete and concise; no unfinished list or trailing colon.
5. Do not add unrelated requirements.
)"
}

; ---------- JSON 字符串转义 / 解析 ----------
JsonStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    return '"' s '"'
}

; 极简提取 choices[0].message.content
ExtractContent(json) {
    if !RegExMatch(json, '"content"\s*:\s*"((?:\\.|[^"])*)"', &m)
        return ""
    c := m[1]
    c := StrReplace(c, '\"', '"')
    c := StrReplace(c, '\\', '\')
    c := StrReplace(c, '\n', '`n')
    c := StrReplace(c, '\r', '`r')
    c := StrReplace(c, '\t', '`t')
    return c
}

; ---------- 调通用 LLM API ----------
Enhance(text) {
    cfg := LoadConfig()
    if (cfg["apiKey"] = "") {
        MsgBox "未配置 API Key。请在 %USERPROFILE%\.prompt-booster\config.json 或环境变量中设置。"
        return ""
    }
    url := cfg["provider"]["baseURL"] "/chat/completions"
    body := '{"model":"' cfg["model"] '","temperature":0.3,"messages":['
         .  '{"role":"system","content":' JsonStr(SYSTEM_PROMPT) '},'
         .  '{"role":"user","content":' JsonStr(UserTemplate(text)) '}]}'

    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    whr.Open("POST", url, true)
    whr.SetRequestHeader("Content-Type", "application/json")
    whr.SetRequestHeader("Authorization", "Bearer " cfg["apiKey"])
    try {
        whr.Send(body)
        whr.WaitForResponse()
        if (whr.Status != 200)
            return ""
        return ExtractContent(whr.ResponseText)
    } catch {
        return ""
    }
}

; ---------- 原地替换 ----------
RunEnhance() {
    oldClip := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(0.5) {
        A_Clipboard := oldClip
        return
    }
    original := Trim(A_Clipboard)
    if (original = "") {
        A_Clipboard := oldClip
        return
    }
    result := Enhance(original)
    if (result = "") {
        A_Clipboard := oldClip
        return
    }
    result := Trim(result)
    result := RegExReplace(result, '^["''“”‘’]+|["''“”‘’]+$', '')
    if (result != "") {
        A_Clipboard := result
        Send "^v"
    }
    Sleep 300
    A_Clipboard := oldClip
}

; ---------- 注册热键 ----------
Hotkey HOTKEY, RunEnhance
