#!/bin/bash
# PromptBooster 安装脚本：编译进 .app 包 + 签名 + 启动
# 首次启动时由应用引导设置快捷键与登录项
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$DIR/PromptBooster.app"
APP_DST="$HOME/Applications/PromptBooster.app"
CONFIG_DIR="$HOME/.prompt-booster"
CONFIG="$CONFIG_DIR/config.json"

echo "==> 0/4 环境检测"
if ! command -v swiftc >/dev/null 2>&1; then
    echo "!! 未找到 swiftc。请先安装 Xcode 命令行工具（约几分钟），然后重新运行本脚本："
    echo "     xcode-select --install"
    exit 1
fi
echo "   swiftc 就绪：$(swiftc --version | head -1)"

echo "==> 1/4 编译进 .app 包（Universal Binary，同时支持 Apple Silicon 与 Intel Mac）"
TMP_BUILD="$(mktemp -d)"
swiftc -O -target arm64-apple-macos12  "$DIR/main.swift" "$DIR/Shortcut.swift" -o "$TMP_BUILD/PromptBooster-arm64"
swiftc -O -target x86_64-apple-macos12 "$DIR/main.swift" "$DIR/Shortcut.swift" -o "$TMP_BUILD/PromptBooster-x86_64"
mkdir -p "$APP_SRC/Contents/MacOS"
lipo -create "$TMP_BUILD/PromptBooster-arm64" "$TMP_BUILD/PromptBooster-x86_64" \
     -output "$APP_SRC/Contents/MacOS/PromptBooster"
rm -rf "$TMP_BUILD"
codesign --force --sign - "$APP_SRC" 2>/dev/null || true

echo "==> 2/4 安装到 ~/Applications"
mkdir -p "$HOME/Applications"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

echo "==> 3/4 生成配置文件模板（已存在则跳过，不会覆盖你的密钥）"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" <<'EOF'
{
  "provider": "deepseek",
  "model": "deepseek-chat",
  "api_key": ""
}
EOF
    echo "   已创建 $CONFIG ，请编辑填入 api_key。"
    echo "   可选 provider: deepseek / zhipu / qwen / moonshot / doubao（见 README）。"
else
    echo "   配置文件已存在，跳过"
fi
chmod 600 "$CONFIG"

echo "==> 4/4 重置本应用历史授权记录并启动"
tccutil reset Accessibility com.promptbooster.app 2>/dev/null || true
killall PromptBooster 2>/dev/null || true
open -a "$APP_DST"

echo ""
echo "✅ 安装完成。接下来两步手动操作："
echo ""
echo "   ① 辅助功能授权（必须）："
echo "      系统设置 → 隐私与安全性 → 辅助功能 → 点 + →"
echo "      按 ⌘⇧G 输入 ~/Applications/PromptBooster.app → 选中 → 打开开关"
echo "      （程序启动时也会主动弹授权窗）"
echo ""
echo "   ② 在首次启动窗口选择快捷键及是否登录时自动启动。"
echo "      以后可在菜单栏 ✦ 随时更改。"
echo ""
echo "   日志：~/.prompt-booster/booster.log"
