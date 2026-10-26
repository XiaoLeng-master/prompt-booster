#!/bin/bash
# PromptBooster 安装脚本：编译 + 生成配置文件模板 + 创建 LaunchAgent（开机自启）
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/prompt-booster"
PLIST="$HOME/Library/LaunchAgents/com.promptbooster.plist"
LABEL="com.promptbooster"
CONFIG_DIR="$HOME/.prompt-booster"
CONFIG="$CONFIG_DIR/config.json"

echo "==> 1/3 编译 Swift 程序"
swiftc -O "$DIR/main.swift" -o "$BIN"

echo "==> 2/3 生成配置文件模板（密钥不写入代码，改由配置文件管理）"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" <<'EOF'
{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "api_key": ""
}
EOF
    echo "   已创建 $CONFIG ，请编辑填入你的 api_key。"
    echo "   可选 provider: deepseek / zhipu / qwen / moonshot / doubao（见 README）。"
else
    echo "   配置文件已存在：$CONFIG（跳过创建，避免覆盖）"
fi
chmod 600 "$CONFIG"

echo "==> 3/3 创建并加载 LaunchAgent（开机自启）"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo ""
echo "✅ 安装完成。"
echo "   1. 编辑配置文件：$CONFIG ，填入 api_key（对应平台的密钥）。"
echo "   2. 首次使用前，到 系统设置 → 隐私与安全性 → 辅助功能，勾选运行本程序的终端/应用。"
echo "   3. 快捷键：⌘⇧E（选中文字后按下即可原地增强）。"
echo "   日志：log show --predicate 'process == \"prompt-booster\"' --last 5m"
