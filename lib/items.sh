# lib/items.sh — 清理项数据模型
# 依赖：lib/ui.sh (human_kb)、lib/progress.sh (scan_spinner_start/stop)
#
# 数据：每个清理项有 5 个平行数组同位置同语义
#   CATS[i]    = 分类名（用于 TUI 的 tab 分组）
#   SIZES_KB[i] = 大小（KB，用于排序、求和、阈值过滤）
#   SIZES[i]   = 人类可读大小（用于显示）
#   DESCS[i]   = 描述（用于显示）
#   CMDS[i]    = 清理命令字符串（由 exec 阶段 eval 执行）

declare -a CATS=()
declare -a SIZES_KB=()
declare -a SIZES=()
declare -a DESCS=()
declare -a CMDS=()

# 注册一个清理项；< 100KB 的项被丢弃（通常是清完后剩的元数据残留）
add_item() {
  local cat="$1" size_kb="$2" desc="$3" cmd="$4"
  [[ -z "$size_kb" || "$size_kb" -lt 100 ]] && return
  CATS+=("$cat")
  SIZES_KB+=("$size_kb")
  SIZES+=("$(human_kb "$size_kb")")
  DESCS+=("$desc")
  CMDS+=("$cmd")
}

# 取目录大小（KB），不存在返回 0；扫描期间显示 spinner + 路径
dir_kb() {
  [[ -e "$1" ]] || { printf '0'; return; }
  scan_spinner_start "$1"
  local k
  k=$(du -sk "$1" 2>/dev/null | awk '{print $1+0}')
  scan_spinner_stop
  printf '%s' "${k:-0}"
}

# 多目录合并大小，逐个 spinner
dirs_kb() {
  local total=0 d k
  for d in "$@"; do
    [[ -e "$d" ]] || continue
    scan_spinner_start "$d"
    k=$(du -sk "$d" 2>/dev/null | awk '{print $1+0}')
    scan_spinner_stop
    total=$(( total + k ))
  done
  printf '%d' "$total"
}
