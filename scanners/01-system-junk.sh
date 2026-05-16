# 系统垃圾：废纸篓 / GoLand 崩溃日志 / 应用崩溃报告 / 老应用日志 / Homebrew 下载缓存

scan_step "废纸篓"
k=$(dir_kb "$HOME/.Trash")
add_item "系统垃圾" "$k" "废纸篓 ~/.Trash" \
  'rm -rf "$HOME/.Trash/"* "$HOME/.Trash/".[!.]* 2>/dev/null; true'

scan_step "GoLand 崩溃日志"
n=$(ls -1 "$HOME"/java_error_in_*.log 2>/dev/null | wc -l | tr -d ' ')
if (( n > 0 )); then
  k=$(du -ck "$HOME"/java_error_in_*.log 2>/dev/null | tail -1 | awk '{print $1+0}')
  add_item "系统垃圾" "$k" "GoLand 崩溃日志 (${n} 个文件)" \
    'rm -f "$HOME"/java_error_in_*.log'
fi

scan_step "应用崩溃报告"
k=$(dir_kb "$HOME/Library/Logs/DiagnosticReports")
add_item "系统垃圾" "$k" "应用崩溃报告 DiagnosticReports" \
  'rm -rf "$HOME/Library/Logs/DiagnosticReports/"* 2>/dev/null; true'

scan_step "30 天以上应用日志"
spinner_start "$HOME/Library/Logs (mtime > 30d)"
k=$(find "$HOME/Library/Logs" -type f -mtime +30 -print0 2>/dev/null \
    | xargs -0 du -ck 2>/dev/null | tail -1 | awk '{print $1+0}')
spinner_stop
if (( ${k:-0} > 0 )); then
  add_item "系统垃圾" "$k" "30 天以上的应用日志" \
    'find "$HOME/Library/Logs" -type f -mtime +30 -delete 2>/dev/null; true'
fi

if command -v brew >/dev/null 2>&1; then
  scan_step "Homebrew 缓存"
  bc=$(brew --cache 2>/dev/null)
  # 只扫 downloads 子目录：cleanup -s 实际就清这里。api/ 和 bootsnap/ 是 brew 自身用的元数据，
  # 不该列入"可清理"。
  if [[ -n "$bc" && -d "$bc/downloads" ]]; then
    k=$(dir_kb "$bc/downloads")
    add_item "系统垃圾" "$k" "Homebrew 下载缓存 ($bc/downloads)" \
      'brew cleanup -s --prune=all >/dev/null 2>&1; true'
  fi
fi
