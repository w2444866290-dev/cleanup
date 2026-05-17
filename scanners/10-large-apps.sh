# 超大 App (≥500MB)：与"不常用 App"可重叠，靠用户在 TUI 中自行判断
# 描述里给出"X 天前用过"或"X 天未用"，方便决策
# 清理命令前加 [[ -e <app> ]] 防御：若用户在"不常用 App"已勾且先执行了，第二次执行静默 noop

scan_step "超大 App 扫描 (≥500MB)"
MIN_APP_MB=500
_now=$(date +%s)
for app_dir in "/Applications" "$HOME/Applications"; do
  [[ -d "$app_dir" ]] || continue
  scan_spinner_start "$app_dir"
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    k=$(du -sk "$app" 2>/dev/null | awk '{print $1+0}')
    (( k < MIN_APP_MB * 1024 )) && continue
    last=$(mdls -name kMDItemLastUsedDate -raw "$app" 2>/dev/null)
    if [[ -z "$last" || "$last" == "(null)" ]]; then
      label="无使用记录"
    else
      last_sec=$(date -j -f '%Y-%m-%d %H:%M:%S %z' "$last" +%s 2>/dev/null)
      if [[ -n "$last_sec" ]]; then
        days=$(( (_now - last_sec) / 86400 ))
        if (( days <= 7 )); then
          label="${days}天前用过"
        else
          label="${days}天未用"
        fi
      else
        label="无使用记录"
      fi
    fi
    name="$(basename "$app")"
    add_item "超大 App (≥500MB)" "$k" "${name}  ${C_DIM}— ${label} — ${app}${C_RESET}" \
      "[[ -e \"$app\" ]] && osascript -e 'tell application \"Finder\" to delete POSIX file \"$app\"' >/dev/null 2>&1; true"
  done < <(find "$app_dir" -maxdepth 2 -name '*.app' -type d 2>/dev/null)
done
scan_spinner_stop
