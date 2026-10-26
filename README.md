# PromptBooster

在**任意输入框**里，选中已写好的文字 → 按快捷键 → 原地增强成更清晰、更具体的 Prompt。

一个极简的跨平台提示词增强工具：目的单一，就是把你已经敲好的那段话，做一次提示词增强。没有多余功能，不收集任何数据——文字只发给你自己配置的大模型 API，密钥存在本机。

## 支持的平台

| 平台 | 目录 | 默认快捷键 | 状态 |
|---|---|---|---|
| macOS | 根目录 | ⌘⇧E | ✅ 可用 |
| Windows | `windows/` | Ctrl+Shift+E | ✅ 可用 |
| Linux | — | — | 暂缓 |
| 手机 | — | — | 暂缓（系统限制，全局读选区不可行） |

## 支持的大模型平台

内置多家国内厂商的**原生 OpenAI 兼容**接入，开箱即用，无需中转：

| provider 值 | 平台 | 默认模型示例 |
|---|---|---|
| `deepseek` | DeepSeek | `deepseek-chat` |
| `zhipu` | 智谱 GLM | `glm-4-plus` |
| `qwen` | 通义千问 | `qwen-plus` |
| `moonshot` | Kimi | `moonshot-v1-8k` |
| `doubao` | 豆包 | 需填 endpoint 对应的模型 id |

> 想加其它厂商，在 `main.swift`（macOS）或 `PromptBooster.ahk`（Windows）的 `LLM_PROVIDERS` / `Providers` 表里加一行即可，只需提供 OpenAI 兼容的 `chat/completions` 基础地址。

## 工作原理

```
选中文字 → 按快捷键
   │  模拟 Ctrl/Cmd+C 读取选区
   ▼
调大模型 API（system + user 提示词模板）
   ▼
去首尾引号 → 模拟 Ctrl/Cmd+V 原地替换
```

## 配置密钥（两种方式，任选其一）

密钥**不写入代码**，仓库不含任何真实密钥。

### 方式一：本地配置文件（推荐）

创建 `~/.prompt-booster/config.json`（Windows 为 `%USERPROFILE%\.prompt-booster\config.json`）：

```json
{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "api_key": "你的密钥"
}
```

参考 [`config.example.json`](config.example.json)。

### 方式二：环境变量

| 变量 | 说明 |
|---|---|
| `PB_PROVIDER` | 平台 id（`deepseek` / `zhipu` / `qwen` / `moonshot` / `doubao`） |
| `PB_MODEL` | 模型名 |
| `<平台>_API_KEY` | 对应平台的密钥，如 `DEEPSEEK_API_KEY`、`ZHIPU_API_KEY`、`QWEN_API_KEY`、`MOONSHOT_API_KEY`、`DOUBAO_API_KEY` |

优先级：**环境变量 > 配置文件**。

## 切换平台 / 模型

改配置里的 `provider` 和 `model` 即可，代码无需改动。例如从 DeepSeek 切到智谱：

```json
{
  "provider": "zhipu",
  "model": "glm-4-plus",
  "api_key": "你的智谱密钥"
}
```

## 快捷键机制

**默认快捷键不跨平台一致**，分别贴合各平台习惯：

| 平台 | 默认 | 是否可自定义 | 修改方式 |
|---|---|---|---|
| macOS | ⌘⇧E | ✅ 可 | 改 `main.swift` 顶部的 `HOTKEY_KEYCODE`（键码）和 `HOTKEY_MODIFIERS`（修饰键），重新 `./install.sh` |
| Windows | Ctrl+Shift+E | ✅ 可 | 改 `PromptBooster.ahk` 顶部的 `HOTKEY` 变量，`^`=Ctrl、`+`=Shift、`!`=Alt、`#`=Win |

macOS 键码参考：`E=14`、`K=40`、`P=35` 等（改键码即可换按键）；修饰键用 `cmdKey`、`shiftKey`、`optionKey`、`controlKey` 组合。

## 安装

### macOS

```bash
./install.sh
```

脚本会：编译 → 生成配置文件模板（`~/.prompt-booster/config.json`）→ 建开机自启。
装完后：① 编辑配置文件填入 `api_key`；② 到「系统设置 → 隐私与安全性 → 辅助功能」授权（这是「原地替换」绕不开的系统限制）。

### Windows

见 [`windows/README.md`](windows/README.md)。

## 卸载

- macOS：`./uninstall.sh`
- Windows：关闭 AHK 进程并删除自启项

## 日志排查（macOS）

```bash
log show --predicate 'process == "prompt-booster"' --last 5m
```

## 许可

MIT
