# PromptBooster

Select text in a supported input field → press a hotkey → it's rewritten in place into a clearer, more specific prompt.

A minimal cross-platform prompt enhancer. Single purpose: enhance already-typed text into a better prompt. Nothing else. No data collection — your text goes only to the model API you configure, and your key stays on your machine.

## Platforms

| Platform | Directory | Default hotkey | Status |
|---|---|---|---|
| macOS | root | ⌘⇧E | ✅ ready |
| Windows | `windows/` | Ctrl+Shift+E | ✅ ready |

## Supported model providers

Several Chinese providers are built in via their **native OpenAI-compatible** endpoints — no relay needed:

| provider | Platform | Example model |
|---|---|---|
| `deepseek` | DeepSeek | `deepseek-chat` |
| `zhipu` | Zhipu GLM | `glm-4-plus` |
| `qwen` | Qwen (Tongyi) | `qwen-plus` |
| `moonshot` | Kimi | `moonshot-v1-8k` |
| `doubao` | Doubao | endpoint-specific model id |

> To add another provider, add one entry to `LLM_PROVIDERS` (`main.swift`) or `Providers` (`PromptBooster.ahk`) — just its OpenAI-compatible `chat/completions` base URL.

## How it works

```
Select text → press hotkey
   │  simulate Ctrl/Cmd+C to read selection
   ▼
Call model API (system + user prompt templates)
   ▼
Strip wrapping quotes → simulate Ctrl/Cmd+V to replace in place
```

## Configuring your key

The key is **not stored in code** — no real keys exist in this repo.

### Option 1: local config file (recommended)

Create `~/.prompt-booster/config.json` (on Windows `%USERPROFILE%\.prompt-booster\config.json`):

```json
{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "api_key": "your-key"
}
```

See [`config.example.json`](config.example.json).

### Option 2: environment variables

| Variable | Meaning |
|---|---|
| `PB_PROVIDER` | provider id (`deepseek` / `zhipu` / `qwen` / `moonshot` / `doubao`) |
| `PB_MODEL` | model name |
| `<PROVIDER>_API_KEY` | e.g. `DEEPSEEK_API_KEY`, `ZHIPU_API_KEY`, `QWEN_API_KEY`, `MOONSHOT_API_KEY`, `DOUBAO_API_KEY` |

Priority: **environment variables > config file**.

## Switching provider / model

Just change `provider` and `model` in the config — no code changes:

```json
{
  "provider": "zhipu",
  "model": "glm-4-plus",
  "api_key": "your-zhipu-key"
}
```

## Hotkey mechanism

Defaults are **per-platform** (not identical across platforms):

| Platform | Default | Customizable | How to change |
|---|---|---|---|
| macOS | ⌘⇧E | ✅ yes | choose on first launch or use the ✦ menu bar item; use at least two modifiers, including Command, Control, or Option |
| Windows | Ctrl+Shift+E | ✅ yes | edit the static hotkey definition at the end of `PromptBooster.ahk`; `^`=Ctrl, `+`=Shift, `!`=Alt, `#`=Win |

If the chosen macOS shortcut cannot be registered, the existing shortcut remains active.

## Install

### macOS

```bash
./install.sh
```

Compiles, generates a config template, and launches the app. On first launch, choose a shortcut and whether to launch at login. You can change both later from the ✦ menu bar item. On macOS 13+, the app registers its own login item; macOS 12 users can add the app manually in System Settings. Then: ① fill `api_key` in the config; ② grant Accessibility permission (System Settings → Privacy & Security → Accessibility) — required for in-place replacement.

### Windows

See [`windows/README.md`](windows/README.md).

## Uninstall

- macOS: `./uninstall.sh` (unregisters the app-managed login item; remove any older manually added login item in System Settings)
- Windows: stop the AHK process and remove the startup item

## Logs (macOS)

```bash
log show --predicate 'process == "prompt-booster"' --last 5m
```

## License

MIT
