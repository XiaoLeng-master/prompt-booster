#!/bin/bash
# PromptBooster 卸载脚本
set -e
PLIST="$HOME/Library/LaunchAgents/com.promptbooster.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "已卸载：已停止常驻进程并移除 LaunchAgent。"
echo "如需彻底删除，请手动删除本目录（prompt-booster）。"
