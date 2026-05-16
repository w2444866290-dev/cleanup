#!/usr/bin/env bash
# cleanup-disk.sh — macOS 交互式磁盘清理（入口脚本）
# 用法: cleanup    （alias 已加到 ~/.zshrc）
#
# 总体流程：
#   1. source 公共库 (lib/ui.sh, lib/progress.sh, lib/items.sh)
#   2. 打印启动横幅 + 当前磁盘状态
#   3. 计算 SCAN_TOTAL（根据已安装工具动态估算扫描步数）
#   4. 顺序 source scanners/*.sh 注册所有清理项（add_item）
#   5. source lib/tui.sh 进入 TUI，让用户多选 + 二次确认
#   6. source lib/exec.sh 真正执行 + 完成报告
#
# 每个 scanner 文件是 sourced 进来的，可直接调用 lib 里的函数；
# 用数字前缀控制 source 顺序，对应 TUI 中 tab 的左→右顺序。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 1) 公共库 ----
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/progress.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/items.sh"

# ---- 2) 启动横幅 ----
clear 2>/dev/null || true
header "磁盘清理 — 扫描中"
print_disk_status
echo
note "正在扫描可清理项，~/go/pkg 较大可能需 ~40 秒..."
echo

START_AVAIL_KB=$(avail_kb /System/Volumes/Data)

# ---- 3) SCAN_TOTAL 预估（根据已安装工具）----
# 步数和 scanners/*.sh 中实际的 scan_step 调用数一致；估算偏小时 scan_step 内会自适应
SCAN_TOTAL=0
SCAN_TOTAL=$((SCAN_TOTAL + 4))  # 01-system-junk: trash/crash/diagreport/老日志
command -v brew >/dev/null 2>&1 && SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 01: brew downloads
SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 02-mounted-dmg
command -v go   >/dev/null 2>&1 && SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 03: go build
SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 03: gopls/goimports
command -v npm  >/dev/null 2>&1 && SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 03: npm
command -v yarn >/dev/null 2>&1 && SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 03: yarn
command -v pnpm >/dev/null 2>&1 && SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 03: pnpm
SCAN_TOTAL=$((SCAN_TOTAL + 2))  # 03: Xcode + Simulator
SCAN_TOTAL=$((SCAN_TOTAL + 4))  # 04-app-caches: JetBrains/Chrome/Lark/Codex
SCAN_TOTAL=$((SCAN_TOTAL + 3))  # 05-careful-data: 壁纸/壁纸代理/QQ音乐
command -v go   >/dev/null 2>&1 && SCAN_TOTAL=$((SCAN_TOTAL + 1))  # 06-go-modcache
# 07-gvm-versions: 每版本 1 步（排除当前活跃 + system + go1.4）
if [[ -d "$HOME/.gvm/gos" ]]; then
  _gvm_count=$(find "$HOME/.gvm/gos" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | grep -vE '/(system|go1\.4)$' | wc -l | tr -d ' ')
  _gvm_count=$(( _gvm_count > 0 ? _gvm_count - 1 : 0 ))
  SCAN_TOTAL=$(( SCAN_TOTAL + _gvm_count ))
fi
SCAN_TOTAL=$((SCAN_TOTAL + 3))  # 08-old-large-files + 09-unused-apps + 10-large-apps

# ---- 4) 依次 source 各 scanner ----
for _scanner in "$SCRIPT_DIR"/scanners/[0-9]*.sh; do
  # shellcheck disable=SC1090
  source "$_scanner"
done
scan_done

# ---- 5) TUI 多选 ----
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/tui.sh"

# ---- 6) 执行 + 完成报告（tui.sh 已确保 SELECTED 非空，否则前面 exit 0）----
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/exec.sh"
