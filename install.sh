#!/bin/bash
# PromptBooster 安装脚本：编译进 .app 包 + 签名 + 启动
# 自启方式：系统登录项（系统设置 → 通用 → 登录项），比 LaunchAgent 更简单可靠
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$DIR/PromptBooster.app"
APP_DST="$HOME/Applications/PromptBooster.app"
CONFIG_DIR="$HOME/.prompt-booster"
CONFIG="$CONFIG_DIR/config.json"

echo "==> 1/4 编译进 .app 包"
swiftc -O "$DIR/main.swift" -o "$APP_SRC/Contents/MacOS/PromptBooster"
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
echo "   ② 开机自启（可选）："
echo "      系统设置 → 通用 → 登录项与扩展 → 登录时打开 → 点 + →"
echo "      选择 ~/Applications/PromptBooster.app"
echo ""
echo "   日志：~/.prompt-booster/booster.log"
