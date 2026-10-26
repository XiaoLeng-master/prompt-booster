# Windows 版

在 Windows 上**选中文字 → 按 Ctrl+Shift+E → 原地增强成清晰 Prompt**。

基于 AutoHotkey v2，密钥不写入代码，改由本地配置文件管理。

## 能否让 AI（如 ChatGPT）协助安装？

**能，但要分清边界。** 让 AI 协助安装是合理的，因为整个过程就是「下载一个软件 + 改一个配置文件」，AI 完全可以一步步指导你执行。但需要注意：

- **AI 只能给你命令和步骤，无法替你在你的 Windows 机器上「点鼠标、输密钥」**——密钥必须由你自己填（AI 也拿不到、也不该拿）。
- 最省事的做法：把下面「一键安装命令」直接粘给 ChatGPT 或本工具，让它陪你逐步跑。

## 安装（三条命令，逐步执行）

### 方式一：winget 一键装 AHK（推荐，Windows 10/11 自带 winget）

```powershell
winget install AutoHotkey.AutoHotkey
```

### 方式二：手动下载

去 <https://www.autohotkey.com/> 下载 **AutoHotkey v2.0**（务必 v2，不是 v1），双击安装。

### 然后：配置密钥并运行

1. 创建配置文件（用记事本或 PowerShell）：

```powershell
# 创建配置目录
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.prompt-booster" | Out-Null

# 写入配置（把「你的密钥」换成真实值，provider 可按需改）
@'
{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "api_key": "你的密钥"
}
'@ | Out-File -Encoding utf8 "$env:USERPROFILE\.prompt-booster\config.json"
```

2. 下载本仓库的 `windows/PromptBooster.ahk`，双击运行（会常驻系统托盘）。
3. 任意输入框选中文字，按 `Ctrl+Shift+E`。

## 编译成独立 exe（可选，免装 AHK）

右键 `PromptBooster.ahk` → **Compile Script**，生成 exe，别的电脑无需装 AHK 也能直接运行。

## 开机自启（可选）

1. 按 `Win+R`，输入 `shell:startup`，回车。
2. 把 `PromptBooster.ahk`（或编译出的 exe）的**快捷方式**放进打开的文件夹。

## 配置与切换平台

配置文件 `%USERPROFILE%\.prompt-booster\config.json`：

```json
{ "provider": "deepseek", "model": "deepseek-chat", "api_key": "..." }
```

`provider` 可选：`deepseek` / `zhipu` / `qwen` / `moonshot` / `doubao`，改完重启脚本生效。
也支持环境变量：`PB_PROVIDER`、`PB_MODEL`、`<平台>_API_KEY`。

## 快捷键

默认 `Ctrl+Shift+E`。改 `PromptBooster.ahk` 顶部 `HOTKEY` 变量：
`^`=Ctrl、`+`=Shift、`!`=Alt、`#`=Win。例如改成 `Alt+E`：

```autohotkey
HOTKEY := "!e"
```

## 说明

与 macOS 版共用同一套提示词与通用大模型接入层，语言一致性、原地替换逻辑完全一致。
