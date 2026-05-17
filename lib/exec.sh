# lib/exec.sh — Whisper UI 执行阶段 + 完成 (zh-CN)
# 依赖：SELECTED[] / CMDS[] / DESCS[] / START_AVAIL_KB

FAIL=0

# ── § 4 清理中 ─────────────────────────────────────────────────
# 开篇 「正在清理 N 项…」；序号 1/3 不带方括号
render_exec_init() {
  local total=$1
  printf '  '
  _paint "正在清理 "    "$C_FG"
  _paint "${total} 项"  "$C_BOLD$C_GREEN"
  _paint "…"            "$C_FG"
  printf '\n'
  nl 1
}

render_exec_running() {
  local cur=$1 total=$2 desc=$3
  printf '\r\033[K  %s%s%s  %s%d/%d%s  %s%s' \
    "$C_CYAN" "${G_SPINNER[$(( $(date +%s%N | cut -c14-) % 10 ))]}" "$C_RESET" \
    "$C_DIM" "$cur" "$total" "$C_RESET" \
    "$C_FG" "$desc"
}

render_exec_result() {
  local cur=$1 total=$2 desc=$3 rc=$4
  local glyph color
  if (( rc == 0 )); then glyph="$G_OK"; color="$C_GREEN"
  else glyph="$G_FAIL"; color="$C_RED"; FAIL=$(( FAIL + 1 ))
  fi
  printf '\r\033[K  %s%s%s  %s%d/%d%s  %s%s%s\n' \
    "$color" "$glyph" "$C_RESET" \
    "$C_DIM" "$cur" "$total" "$C_RESET" \
    "$C_FG" "$desc" "$C_RESET"
}

_total=${#SELECTED[@]}
render_exec_init "$_total"
_cur=0
for n in "${SELECTED[@]}"; do
  idx=$((n-1))
  _cur=$((_cur+1))
  desc="${DESCS[$idx]}"
  render_exec_running "$_cur" "$_total" "$desc"
  # subshell isolation: set +u for sourced GVM scripts; </dev/null to stop stdin
  # blocking; ( ... ) so an `exit` in sourced cmd only kills the subshell
  if ( set +u; eval "${CMDS[$idx]}" ) </dev/null >/dev/null 2>&1; then
    render_exec_result "$_cur" "$_total" "$desc" 0
  else
    render_exec_result "$_cur" "$_total" "$desc" 1
  fi
done

# ── § 5 完成 ──────────────────────────────────────────────────
END_AVAIL_KB=$(avail_kb /System/Volumes/Data)
FREED_KB=$(( END_AVAIL_KB - START_AVAIL_KB ))

# 一句话开头 「✓ 清理完成，本次释放约 X G。」
render_done() {
  if (( FREED_KB > 0 )); then
    local freed_h; freed_h=$(human_kb "$FREED_KB")
    printf '  '
    _paint "${G_OK} "                "$C_BOLD$C_GREEN"
    _paint "清理完成，本次释放约 "    "$C_FG"
    _paint "$freed_h"                "$C_BOLD$C_GREEN"
    _paint "。"                       "$C_FG"
    printf '\n'
  else
    printf '  '
    _paint "清理完成。本次未观测到空间增加，文件可能仍在废纸篓或被占用。" "$C_DIM"
    printf '\n'
  fi
  nl 1
  print_disk_status
  if (( FAIL > 0 )); then
    nl 1
    printf '  '
    _paint "${G_WARN}  "                                "$C_YELLOW"
    _paint "${FAIL} 项执行返回非 0（可能文件被占用）"   "$C_DIM"
    printf '\n'
  fi
  nl 2
  printf '  '; _paint "提示：移到废纸篓的文件需在 Finder 清空废纸篓后" "$C_DIM"; printf '\n'
  printf '  '; _paint "       才会真正腾出空间。"                       "$C_DIM"; printf '\n'
}

nl 1
render_done
