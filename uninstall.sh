#!/bin/bash
# PromptBooster 卸载脚本
set -e
killall PromptBooster 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.promptbooster.plist 2>/dev/null || true
rm -rf ~/Applications/PromptBooster.app
echo "已卸载：进程已停止、App 已删除。"
echo "如需彻底清理（含密钥与日志），再执行：rm -rf ~/.prompt-booster"
echo "记得到 系统设置 → 通用 → 登录项 移除 PromptBooster（如有添加）。"
