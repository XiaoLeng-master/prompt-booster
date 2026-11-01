#!/bin/bash
# PromptBooster 卸载脚本
set -e
APP="$HOME/Applications/PromptBooster.app"
if [ -x "$APP/Contents/MacOS/PromptBooster" ]; then
    "$APP/Contents/MacOS/PromptBooster" --unregister-login
fi
killall PromptBooster 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.promptbooster.plist 2>/dev/null || true
rm -rf "$APP"
echo "已卸载：进程已停止、App 已删除。"
echo "如需彻底清理（含密钥与日志），再执行：rm -rf ~/.prompt-booster"
echo "若曾手动添加过登录项，请到系统设置 → 通用 → 登录项移除旧条目。"
