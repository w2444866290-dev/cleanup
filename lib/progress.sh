# lib/progress.sh — 进度条 + spinner（后台进程在 /dev/tty 上实时刷新）
# 依赖：lib/ui.sh（颜色变量）
# 共享变量：SCAN_STEP / SCAN_TOTAL（由入口脚本预先初始化）

: "${SCAN_STEP:=0}"
: "${SCAN_TOTAL:=1}"
BAR_WIDTH=24
SPIN_CHARS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPIN_PID=""

# spinner 后台进程：每 100ms 在 /dev/tty 上刷新一次
#   [N/M] ████░░░░ 50% ⠋ <path> 12s
# 父进程做实际工作（du / find / ...），结束后调 spinner_stop
spinner_start() {
  [[ -n "${SPIN_PID:-}" ]] && spinner_stop
  local path="$1"
  local step=$SCAN_STEP total=$SCAN_TOTAL
  (( step > total )) && total=$step
  local filled=$(( step * BAR_WIDTH / total ))
  (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH
  local empty=$(( BAR_WIDTH - filled ))
  local bar="" j
  for ((j=0; j<filled; j++)); do bar+="█"; done
  for ((j=0; j<empty;  j++)); do bar+="░"; done
  local pct=$(( step * 100 / total ))
  local start
  start=$(date +%s)
  (
    local i=0 ch elapsed time_label
    while :; do
      elapsed=$(( $(date +%s) - start ))
      time_label=""
      (( elapsed >= 2 )) && time_label="  ${C_YELLOW}${elapsed}s${C_RESET}"
      ch="${SPIN_CHARS[$((i % 10))]}"
      printf '\r  %s[%2d/%d]%s %s%s%s %s%3d%%%s  %s%s%s  %s%s%s%s\033[K' \
        "$C_BOLD" "$step" "$total" "$C_RESET" \
        "$C_GREEN" "$bar" "$C_RESET" \
        "$C_CYAN" "$pct" "$C_RESET" \
        "$C_BOLD" "$ch" "$C_RESET" \
        "$C_DIM" "$path" "$C_RESET" \
        "$time_label" > /dev/tty 2>/dev/null
      sleep 0.1
      i=$((i + 1))
    done
  ) &
  SPIN_PID=$!
}

spinner_stop() {
  if [[ -n "${SPIN_PID:-}" ]]; then
    kill "$SPIN_PID" 2>/dev/null
    wait "$SPIN_PID" 2>/dev/null
    SPIN_PID=""
  fi
}

# 任何方式退出都把 spinner 杀掉（避免后台进程残留）
trap 'spinner_stop 2>/dev/null' EXIT

# 同步进度条（无 spinner，用于快项扫描）
scan_step() {
  SCAN_STEP=$((SCAN_STEP + 1))
  local total=$SCAN_TOTAL
  (( SCAN_STEP > total )) && total=$SCAN_STEP
  local filled=$(( SCAN_STEP * BAR_WIDTH / total ))
  (( filled > BAR_WIDTH )) && filled=$BAR_WIDTH
  local empty=$(( BAR_WIDTH - filled ))
  local bar="" i
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty;  i++)); do bar+="░"; done
  local pct=$(( SCAN_STEP * 100 / total ))
  printf '\r  %s[%2d/%d]%s %s%s%s %s%3d%%%s  %s\033[K' \
    "$C_BOLD" "$SCAN_STEP" "$total" "$C_RESET" \
    "$C_GREEN" "$bar" "$C_RESET" \
    "$C_CYAN" "$pct" "$C_RESET" \
    "$1"
}

# 扫描完成后清掉进度行（\r\033[K 把整行刷干净）
scan_done() {
  printf '\r\033[K'
}
