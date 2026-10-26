# PromptBooster

**在支持的桌面应用中，选中文字 → 按快捷键 → 优化提示词并在原处替换。**

一个轻量开源的提示词增强工具。目的只有一个：把选中的文字改写成更清晰的提示词。密钥保存在本机，选中的文字会发送给你配置的模型服务；本项目不设中间服务器。

## 它解决什么问题

你对着 ChatGPT / Claude / Cursor 打了一句「帮我写个爬虫」，然后发现输出不是你想要的，又得重新组织语言描述半天。PromptBooster 把这一步自动化：

```
之前：「帮我写个爬虫」
之后：「编写一个 Python 网页爬虫，要求：1）支持自定义目标 URL 和 CSS 选择器；
      2）处理常见反爬机制（UA 伪装、请求间隔）；3）异常捕获与日志；
      4）结果存为结构化 CSV……」
```

全程不切换窗口、不复制粘贴，选中按快捷键即可。

## 特性

- **全局快捷键**：在支持读取选区和回填文字的应用中使用；macOS 版已在微信中验证，其他应用的兼容性取决于其输入框实现
- **原地替换**：结果直接替换选中文字，不打断思路
- **语言一致**：中文输入出中文、英文出英文、混合保持混合
- **多模型**：内置多家国内厂商接入，改一行配置即可切换
- **隐私安全**：密钥存本机，请求直连模型厂商，无中间服务器、无遥测
- **轻量常驻**：无界面，几 MB 内存占用，开机自启

## 支持的平台

| 平台 | 目录 | 默认快捷键 | 状态 |
|---|---|---|---|
| macOS | 根目录 | ⌘⇧E | ✅ 可用 |
| Windows | `windows/` | Ctrl+Shift+E | ⚠️ 脚本已实现，待实机验证 |

## 支持的大模型平台

内置以下厂商的**原生 OpenAI 兼容**接口，开箱即用：

| `provider` | 平台 | 模型示例 |
|---|---|---|
| `deepseek` | DeepSeek | `deepseek-chat` |
| `zhipu` | 智谱 GLM | `glm-4-plus` |
| `qwen` | 通义千问 | `qwen-plus` |
| `moonshot` | Kimi | `moonshot-v1-8k` |
| `doubao` | 豆包（火山方舟） | 填你 endpoint 绑定的模型 id |

> 想接其他厂商（包括 OpenAI、Claude 等任何 OpenAI 兼容接口），在 `main.swift`（macOS）或 `PromptBooster.ahk`（Windows）的 `LLM_PROVIDERS` / `Providers` 表里加一行——只需平台名和 `chat/completions` 基础地址。

## 环境要求

本工具**没有第三方包依赖**，只需要系统自带或一个免费工具：

| 平台 | 要求 |
|---|---|
| macOS 12+ | Xcode 命令行工具（编译用，`xcode-select --install` 免费安装）；Apple Silicon 与 Intel 均支持（Universal Binary） |
| Windows 10/11 | [AutoHotkey **v2**](https://www.autohotkey.com/)（⚠️ v1 语法不兼容，务必 v2） |

> 本项目不使用 Python / Node，无需 pip / npm 安装任何东西。

## 安装

### macOS（3 步）

```bash
# 1. 克隆并编译安装（编译进 .app 包 + 签名 + 启动）
git clone https://github.com/XiaoLeng-master/prompt-booster.git
cd prompt-booster
./install.sh

# 2. 编辑配置，填入密钥
nano ~/.prompt-booster/config.json
```

程序会安装到 `~/Applications/PromptBooster.app` 并自动启动。

配置内容：

```json
{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "api_key": "你的密钥"
}
```

**最后一步（必须）**：系统设置 → 隐私与安全性 → 辅助功能 → 点 `+` → 按 `⌘⇧G` 输入 `~/Applications/PromptBooster.app` → 选中 → 打开开关。程序启动时也会主动弹窗提示。

**开机自启（可选）**：系统设置 → 通用 → 登录项与扩展 → 登录时打开 → 点 `+` → 选择 `~/Applications/PromptBooster.app`。

> ⚠️ **重要**：每次重新编译后，macOS 的代码签名会变化，**之前的授权会失效**。`install.sh` 已自动处理（重置本应用的授权记录），你只需重新添加并打开开关。如果发现「明明开了还是没反应」，先想到这一条。

### Windows（3 步）

```powershell
# 1. 安装 AutoHotkey v2（务必 v2，不是 v1）
winget install AutoHotkey.AutoHotkey

# 2. 创建配置文件（把「你的密钥」换成真实值）
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.prompt-booster" | Out-Null
@'
{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "api_key": "你的密钥"
}
'@ | Out-File -Encoding utf8 "$env:USERPROFILE\.prompt-booster\config.json"

# 3. 下载仓库中的 windows/PromptBooster.ahk，双击运行（常驻托盘）
```

可选：右键 `PromptBooster.ahk` → Compile Script 编译成独立 exe，其他电脑免装 AHK。
可选：把脚本快捷方式放进 `shell:startup` 文件夹实现开机自启。

也可以让 AI（ChatGPT 等）协助安装——把上面的命令逐条贴给它，让它陪你跑，但**密钥必须你自己填**。

## 配置说明

配置文件位置：

- macOS：`~/.prompt-booster/config.json`
- Windows：`%USERPROFILE%\.prompt-booster\config.json`

| 字段 | 说明 | 示例 |
|---|---|---|
| `provider` | 平台 id（见上方表格） | `deepseek` |
| `model` | 模型名 | `deepseek-chat` |
| `api_key` | 对应平台的密钥 | `sk-...` |

也支持环境变量（优先级**高于**配置文件）：`PB_PROVIDER`、`PB_MODEL`、`<平台>_API_KEY`（如 `DEEPSEEK_API_KEY`、`ZHIPU_API_KEY`、`QWEN_API_KEY`、`MOONSHOT_API_KEY`、`DOUBAO_API_KEY`）。

**切换平台**只需改 `provider` 和 `model` 两个字段，例如切到智谱：

```json
{
  "provider": "zhipu",
  "model": "glm-4-plus",
  "api_key": "你的智谱密钥"
}
```

改完重启进程生效（macOS：`killall prompt-booster`，launchd 会自动拉起；Windows：退出托盘图标后重新双击脚本）。

## 快捷键

默认快捷键**不跨平台一致**，贴合各平台习惯：

| 平台 | 默认 | 自定义方法 |
|---|---|---|
| macOS | ⌘⇧E | 改 `main.swift` 顶部 `HOTKEY_KEYCODE`（键码：E=14、K=40、P=35…）和 `HOTKEY_MODIFIERS`（`cmdKey` / `shiftKey` / `optionKey` / `controlKey` 组合），重新 `./install.sh` |
| Windows | Ctrl+Shift+E | 改 `PromptBooster.ahk` 末尾的静态热键定义：`^`=Ctrl、`+`=Shift、`!`=Alt、`#`=Win，如 `!e::RunEnhance()` 为 Alt+E |

> 注意：如果快捷键被其他应用占用，注册会失败——日志里会明确提示「快捷键注册失败」，换一个组合即可。

## 排障

程序运行日志写在 `~/.prompt-booster/booster.log`（macOS），每次按快捷键的完整链路都会记录：

```
快捷键已触发 → 读选区完成，长度=N → 原地替换完成，长度=M
```

常见问题：

| 现象 | 原因与解决 |
|---|---|
| 按快捷键完全没反应，日志无「快捷键已触发」 | 快捷键注册失败（被占用）或进程没在跑。查日志首行；macOS 执行 `open -a ~/Applications/PromptBooster.app` 重启 |
| 日志显示「选区为空」 | 辅助功能未授权，或重新编译后授权失效——移除旧条目重新添加 |
| 日志显示「API 调用失败」 | 密钥无效 / 余额不足 / 模型名错误。先确认配置正确 |
| 授权开关明明是开的，还是没反应 | 重编译导致签名变化、授权失效。移除条目 → 重新添加 → 打开 |

## 卸载

```bash
# macOS
./uninstall.sh            # 停止进程、删除 App
rm -rf ~/.prompt-booster  # 删除配置与日志（含密钥）
```

Windows：退出托盘进程、删除 `shell:startup` 里的自启项和脚本文件即可。

## 从 Release 下载 .app 的注意事项

如果使用他人（或 CI）编译好的 `.app`（而非自己编译），由于未经 Apple 公证，首次打开可能提示「已损坏」或被 Gatekeeper 拦截。执行一次：

```bash
xattr -cr /Applications/PromptBooster.app   # 路径按实际安装位置调整
```

然后正常打开即可。最稳妥的方式始终是**自己源码编译**（`./install.sh`），不经过网络分发二进制。

## 隐私说明

- 选中的文字**只发送给你配置的模型厂商**，本工具不经过任何中间服务器
- 密钥保存在本机配置文件中（建议 `chmod 600`，安装脚本已自动设置）
- 不上传、不缓存、不遥测

## License

MIT
