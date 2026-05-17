# lib/ui.sh — Whisper UI 设计语言：颜色 / 字符 / 布局 / 通用渲染辅助 (zh-CN)
# 依赖：无

# ── colors ────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  if [[ "${TERM:-}" != "dumb" ]] && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]]; then
    C_FG="$(printf '\033[38;5;253m')"
    C_FAINT="$(printf '\033[38;5;243m')"
    C_GREEN="$(printf '\033[38;5;108m')"
    C_YELLOW="$(printf '\033[38;5;179m')"
    C_RED="$(printf '\033[38;5;167m')"
    C_CYAN="$(printf '\033[38;5;108m')"
    C_BLUE="$(printf '\033[38;5;109m')"
  else
    C_FG=""
    C_FAINT="$(printf '\033[2m')"
    C_GREEN="$(printf '\033[32m')"
    C_YELLOW="$(printf '\033[33m')"
    C_RED="$(printf '\033[31m')"
    C_CYAN="$(printf '\033[36m')"
    C_BLUE="$(printf '\033[34m')"
  fi
  C_DIM="$(printf '\033[2m')"
  C_BOLD="$(printf '\033[1m')"
  C_RESET="$(printf '\033[0m')"
else
  C_FG="" C_FAINT="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN="" C_BLUE=""
  C_DIM="" C_BOLD="" C_RESET=""
fi

# ── glyphs ────────────────────────────────────────────────────
G_CURSOR="▸"
G_BOX_EMPTY="◯"
G_BOX_FULL="●"
G_KICKER_SEP="·"          # confirm 分类项目符仍用
G_CAT_BULLET="·"
G_BAR_FILL="━"
G_BAR_EMPTY="━"
G_OK="✓"
G_FAIL="✗"
G_WARN="!"
G_ELLIPSIS="…"
G_ARROW_UP="↑"
G_ARROW_DOWN="↓"
G_SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

# ── layout ────────────────────────────────────────────────────
LAYOUT_WIDTH=64
LAYOUT_GUTTER=2
LAYOUT_BAR_WIDTH=49
LAYOUT_LIST_MAX=7

# ── general helpers ───────────────────────────────────────────

# repeat CHAR N times
_repeat() {
  local ch=$1 n=$2
  (( n <= 0 )) && return
  local out; out=$(printf "%${n}s" "")
  printf '%s' "${out// /$ch}"
}

# print N empty lines
nl() { local n=${1:-1}; while (( n-- > 0 )); do printf '\n'; done; }

# ── width-aware string helpers (§ 0.4) ────────────────────────
# bash 3.2 compatibility: decode UTF-8 byte-by-byte under LC_ALL=C, mask with
# & 0xFF (because `'X` returns SIGNED byte values in 3.2: 0xE6 → -26).
_vwidth() {
  local s=$1
  while [[ $s =~ $'\033'\[[0-9\;]*m ]]; do s=${s/${BASH_REMATCH[0]}/}; done
  local LC_ALL=C
  local i=0 len=${#s} b0 b1 b2 cp cells=0
  while (( i < len )); do
    printf -v b0 '%d' "'${s:i:1}"; b0=$(( b0 & 0xFF ))
    if   (( b0 < 0x80 )); then cp=$b0; i=$((i+1))
    elif (( b0 < 0xC0 )); then i=$((i+1)); continue
    elif (( b0 < 0xE0 )); then
      printf -v b1 '%d' "'${s:i+1:1}"; b1=$(( b1 & 0xFF ))
      cp=$(( (b0 & 0x1F) << 6 | (b1 & 0x3F) )); i=$((i+2))
    elif (( b0 < 0xF0 )); then
      printf -v b1 '%d' "'${s:i+1:1}"; b1=$(( b1 & 0xFF ))
      printf -v b2 '%d' "'${s:i+2:1}"; b2=$(( b2 & 0xFF ))
      cp=$(( (b0 & 0x0F) << 12 | (b1 & 0x3F) << 6 | (b2 & 0x3F) )); i=$((i+3))
    else
      cp=0; i=$((i+4))
    fi
    if   (( cp >= 0x1100 && cp <= 0x115F )) || (( cp >= 0x2E80 && cp <= 0x303E )) || \
         (( cp >= 0x3041 && cp <= 0x33FF )) || (( cp >= 0x3400 && cp <= 0x4DBF )) || \
         (( cp >= 0x4E00 && cp <= 0x9FFF )) || (( cp >= 0xAC00 && cp <= 0xD7A3 )) || \
         (( cp >= 0xF900 && cp <= 0xFAFF )) || (( cp >= 0xFE30 && cp <= 0xFE4F )) || \
         (( cp >= 0xFF00 && cp <= 0xFF60 )) || (( cp >= 0xFFE0 && cp <= 0xFFE6 )); then
      cells=$((cells + 2))
    else
      cells=$((cells + 1))
    fi
  done
  printf '%d' "$cells"
}

# left-pad string to target display columns (no truncation if overflow)
_lpad_to() {
  local s=$1 target=$2
  local w; w=$(_vwidth "$s")
  local pad=$(( target - w )); (( pad < 0 )) && pad=0
  printf '%s%*s' "$s" "$pad" ""
}

# right-pad string to target display columns
_rpad_to() {
  local s=$1 target=$2
  local w; w=$(_vwidth "$s")
  local pad=$(( target - w )); (( pad < 0 )) && pad=0
  printf '%*s%s' "$pad" "" "$s"
}

# _paint TEXT COLOR — 输出 "${COLOR}${TEXT}${C_RESET}"
_paint() {
  printf '%s%s%s' "$2" "$1" "$C_RESET"
}

# ── disk values ───────────────────────────────────────────────

# available KB on a mount, for FREED_KB delta
avail_kb() { df -k "$1" 2>/dev/null | awk 'NR==2 {print $4}'; }

# KB → human readable: "8K" / "1.2M" / "27.3G"
human_kb() {
  awk -v k="$1" 'BEGIN{
    if(k>=1024*1024) printf "%.1fG", k/1024/1024;
    else if(k>=1024) printf "%.1fM", k/1024;
    else printf "%dK", k
  }'
}

# four df fields, native units kept (e.g. "460Gi 326Gi 110Gi 75")
_df_values() {
  df -h /System/Volumes/Data 2>/dev/null | awk 'NR==2 {
    gsub(/%$/, "", $5);
    print $2, $3, $4, $5
  }'
}

# disk readout (§ 0.5) — 句子化：磁盘已用 75%（326Gi/460Gi），剩余 110Gi
print_disk_status() {
  local total used free pct
  read -r total used free pct < <(_df_values)
  printf '  '
  _paint "磁盘已用 "      "$C_DIM"
  _paint "${pct}%"        "$C_FG"
  _paint "（"              "$C_DIM"
  _paint "$used"          "$C_FG"
  _paint "/"              "$C_DIM"
  _paint "$total"         "$C_FG"
  _paint "），剩余 "       "$C_DIM"
  _paint "$free"          "$C_BOLD$C_GREEN"
  printf '\n'
}
