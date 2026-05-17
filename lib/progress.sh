# lib/progress.sh — Whisper UI 扫描阶段：两行进度条 + 异步 spinner (zh-CN)
# 依赖：lib/ui.sh
# 共享变量：SCAN_STEP / SCAN_TOTAL（由入口脚本初始化）

: "${SCAN_STEP:=0}"
: "${SCAN_TOTAL:=1}"

SPINNER_PID=""
SPINNER_PATH=""
SPINNER_START_TS=0
SPINNER_IDX=0

# /dev/tty may be missing (non-tty env / piped). gate spinner output on it.
if { : >/dev/tty; } 2>/dev/null; then
  _HAVE_TTY=1
else
  _HAVE_TTY=0
fi

# ── 1.1 启动横幅 ──────────────────────────────────────────────
# 没有 kicker，第一行就是动作句
scan_init() {
  printf '  '
  _paint "正在扫描可清理项"      "$C_FG"
  _paint "，"                     "$C_DIM"
  _paint "~/go/pkg"              "$C_FG"
  _paint " 较大，预计需要 ~40 秒" "$C_DIM"
  printf '\n'
  nl 1
  print_disk_status
}

# ── 1.2 进度条（两行原地刷新）────────────────────────────────
# 第一行 "正在扫描 cur/total 项…" + 右对齐 pct，第二行 bar
# Args: $1 = "current label" (ignored visually, retained for compat)
scan_step() {
  SCAN_STEP=$((SCAN_STEP + 1))
  local cur=$SCAN_STEP total=$SCAN_TOTAL
  (( cur > total )) && total=$cur
  local pct=$(( cur * 100 / total ))
  local filled=$(( cur * LAYOUT_BAR_WIDTH / total ))
  (( filled > LAYOUT_BAR_WIDTH )) && filled=$LAYOUT_BAR_WIDTH
  local empty=$(( LAYOUT_BAR_WIDTH - filled ))

  local left="正在扫描 ${cur}/${total} 项…"
  local left_w; left_w=$(_vwidth "$left")
  local pct_str; pct_str=$(printf '%d%%' "$pct")
  local pct_w; pct_w=$(_vwidth "$pct_str")
  local mid_pad=$(( LAYOUT_WIDTH - left_w - pct_w )); (( mid_pad < 1 )) && mid_pad=1

  printf '\r\033[K  '
  _paint "正在扫描 "         "$C_FG"
  _paint "${cur}/${total}"   "$C_FAINT"
  _paint " 项…"              "$C_FG"
  printf '%*s' "$mid_pad" ""
  _paint "$pct_str"          "$C_FG"
  printf '\n'

  printf '\033[K  '
  _paint "$(_repeat "$G_BAR_FILL"  "$filled")" "$C_GREEN"
  _paint "$(_repeat "$G_BAR_EMPTY" "$empty")"  "$C_DIM"
  printf '\n'

  # cursor back up to step line for next overwrite
  printf '\033[2A'
}

# ── 1.3 进度条 + spinner（慢项）───────────────────────────────
scan_spinner_start() {
  [[ -n "${SPINNER_PID:-}" ]] && scan_spinner_stop
  (( _HAVE_TTY == 0 )) && return
  SPINNER_PATH="$1"
  SPINNER_START_TS=$(date +%s)
  SPINNER_IDX=0
  ( while :; do
      scan_spinner_tick
      sleep 0.1
    done ) >/dev/tty 2>/dev/null &
  SPINNER_PID=$!
}

# spinner 行右端 "已用 NNs"
scan_spinner_tick() {
  local now=$(date +%s)
  local elapsed=$(( now - SPINNER_START_TS ))
  (( elapsed < 2 )) && return     # only show after ≥ 2s

  local glyph=${G_SPINNER[$(( SPINNER_IDX % 10 ))]}
  SPINNER_IDX=$(( SPINNER_IDX + 1 ))

  # 路径字段 = 64 - 2(gutter) - 1(spinner) - 2(sep) - 7(右端 " 已用 NNs") ≈ 52
  local path_w; path_w=$(_vwidth "$SPINNER_PATH")
  local pad=$(( 52 - path_w )); (( pad < 1 )) && pad=1

  printf '\033[s\033[2B\r\033[K  %s%s%s  %s%s%s%*s%s已用 %s%s%ds%s\033[u' \
    "$C_CYAN"   "$glyph"        "$C_RESET" \
    "$C_DIM"    "$SPINNER_PATH" "$C_RESET" \
    "$pad" "" \
    "$C_DIM"    "$C_RESET" \
    "$C_YELLOW" "$elapsed"      "$C_RESET" >/dev/tty
}

scan_spinner_stop() {
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null
    SPINNER_PID=""
  fi
  (( _HAVE_TTY == 1 )) && printf '\033[s\033[2B\r\033[K\033[u' >/dev/tty 2>/dev/null
}

trap 'scan_spinner_stop 2>/dev/null' EXIT

# ── 1.4 扫描完成 ──────────────────────────────────────────────
scan_done() {
  scan_spinner_stop
}
