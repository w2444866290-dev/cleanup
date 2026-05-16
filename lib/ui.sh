# lib/ui.sh — 颜色变量 + 输出 helper（无副作用、可被任何模块 source）
# 依赖：无

# ---- 颜色 ----
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

# ---- 分隔线 / 标题 ----
hr()     { printf '%s\n' "================================================================"; }
hr2()    { printf '%s\n' "----------------------------------------------------------------"; }
header() { hr; printf '%s%s%s\n' "$C_BOLD$C_BLUE" "$1" "$C_RESET"; hr; }

# ---- 单行状态 ----
note() { printf '  %s%s%s\n' "$C_DIM"    "$1" "$C_RESET"; }
ok()   { printf '  %s✓%s %s\n' "$C_GREEN"  "$C_RESET" "$1"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
err()  { printf '  %s✗%s %s\n' "$C_RED"    "$C_RESET" "$1"; }

# ---- 磁盘可用容量（KB） ----
avail_kb() { df -k "$1" 2>/dev/null | awk 'NR==2 {print $4}'; }

# ---- KB → 人类可读 ("8K" / "1.2M" / "27.3G") ----
human_kb() {
  awk -v k="$1" 'BEGIN{
    if(k>=1024*1024) printf "%.1fG", k/1024/1024;
    else if(k>=1024) printf "%.1fM", k/1024;
    else printf "%dK", k
  }'
}

# ---- 当前磁盘状态：每个字段都有中文标签 ----
print_disk_status() {
  local line size used avail pct
  line=$(df -h /System/Volumes/Data | awk 'NR==2')
  size=$(echo "$line"  | awk '{print $2}')
  used=$(echo "$line"  | awk '{print $3}')
  avail=$(echo "$line" | awk '{print $4}')
  pct=$(echo "$line"   | awk '{print $5}')
  printf '  %s总容量%s %s   %s已用%s %s   %s可用%s %s%s   %s占用%s %s\n' \
    "$C_DIM" "$C_RESET" "$size" \
    "$C_DIM" "$C_RESET" "$used" \
    "$C_DIM" "$C_RESET" "$C_BOLD$C_GREEN" "$avail$C_RESET" \
    "$C_DIM" "$C_RESET" "$pct"
}
