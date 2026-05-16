# lib/exec.sh — 真正执行清理 + 末尾报告
# 依赖：SELECTED[] / CMDS[] / DESCS[] / START_AVAIL_KB
# 每条清理命令在隔离的 subshell 中执行（详见下方注释）

echo
header "开始清理"
DONE=0
FAIL=0
for n in "${SELECTED[@]}"; do
  idx=$((n-1))
  DONE=$((DONE+1))
  printf '  [%d/%d] %s%s%s ... ' "$DONE" "${#SELECTED[@]}" "$C_BOLD" "${DESCS[$idx]}" "$C_RESET"
  # 在 subshell 里执行：
  #   1) `set +u` 关闭未定义变量检查 —— 否则 `source ~/.gvm/scripts/gvm` 等外部
  #      脚本展开未定义变量时会让整个父脚本退出
  #   2) </dev/null 防 gvm/osascript 等命令读 stdin 阻塞
  #   3) subshell 隔离，即使 cmd 调用 exit 也只杀 subshell，主进程不受影响
  if ( set +u; eval "${CMDS[$idx]}" ) </dev/null; then
    printf '%s✓%s\n' "$C_GREEN" "$C_RESET"
  else
    printf '%s✗%s\n' "$C_RED" "$C_RESET"
    FAIL=$((FAIL+1))
  fi
done

# ---- 末尾报告 ----
END_AVAIL_KB=$(avail_kb /System/Volumes/Data)
FREED_KB=$(( END_AVAIL_KB - START_AVAIL_KB ))
echo
header "完成"
print_disk_status
if (( FREED_KB > 0 )); then
  ok "本次释放约 $(human_kb "$FREED_KB")"
else
  note "本次未观测到空间增加（可能项目刚被移到废纸篓，需手动清空才会真正释放）"
fi
(( FAIL > 0 )) && warn "$FAIL 项执行返回非 0（可能文件被占用）"
echo
note "提示：移到废纸篓的文件/App 在 Finder 清空废纸篓后才会真正腾出空间。"
