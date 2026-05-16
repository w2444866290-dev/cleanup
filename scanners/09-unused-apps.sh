# 不常用 App：180 天没启动的 App，扫 /Applications + ~/Applications
# 使用 Spotlight 元数据 kMDItemLastUsedDate；拿不到时退化用 mtime（不准但保守）

scan_step "不常用 App（180 天+ 未启动）"
APP_OLD_DAYS=180
NOW=$(date +%s)
THRESHOLD=$(( APP_OLD_DAYS * 86400 ))
for app_dir in "/Applications" "$HOME/Applications"; do
  [[ -d "$app_dir" ]] || continue
  spinner_start "$app_dir"
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    last=$(mdls -name kMDItemLastUsedDate -raw "$app" 2>/dev/null)
    if [[ -z "$last" || "$last" == "(null)" ]]; then
      last_sec=$(stat -f '%m' "$app" 2>/dev/null) || continue
      last_label="无使用记录"
    else
      last_sec=$(date -j -f '%Y-%m-%d %H:%M:%S %z' "$last" +%s 2>/dev/null) || continue
      last_label="$(date -r "$last_sec" '+%Y-%m-%d')"
    fi
    age=$(( NOW - last_sec ))
    (( age <= THRESHOLD )) && continue
    days=$(( age / 86400 ))
    k=$(du -sk "$app" 2>/dev/null | awk '{print $1+0}')
    name="$(basename "$app")"
    add_item "不常用 App (180天+ 未启动)" "$k" "${name}  ${C_DIM}— ${days} 天未用 (${last_label}) — ${app}${C_RESET}" \
      "osascript -e 'tell application \"Finder\" to delete POSIX file \"$app\"' >/dev/null 2>&1; true"
  done < <(find "$app_dir" -maxdepth 2 -name '*.app' -type d 2>/dev/null)
done
spinner_stop
