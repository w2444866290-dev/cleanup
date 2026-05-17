# 旧大文件：扫 ~/Downloads ~/Desktop ~/Documents ~/Movies ~/Pictures
# 条件：≥100MB 且 180 天没访问。每个文件作为独立项
# 清理方式：osascript 走 Finder 移到废纸篓，**可从废纸篓恢复**

scan_step "旧大文件（180 天+ ≥100MB）"
OLD_DAYS=180
MIN_MB=100
for d in "$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents" "$HOME/Movies" "$HOME/Pictures"; do
  [[ -d "$d" ]] || continue
  scan_spinner_start "$d"
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    sz=$(stat -f '%z' "$f" 2>/dev/null) || continue
    k=$(( sz / 1024 ))
    atime=$(stat -f '%Sa' -t '%Y-%m-%d' "$f" 2>/dev/null)
    add_item "旧大文件 (180天+ ≥100MB)" "$k" "$(basename "$f")  ${C_DIM}— $atime — $f${C_RESET}" \
      "osascript -e 'tell application \"Finder\" to delete POSIX file \"$f\"' >/dev/null 2>&1; true"
  done < <(find "$d" -type f -size +"${MIN_MB}"M -atime +"${OLD_DAYS}" \
              -not -path '*/*.app/*' -not -path '*/node_modules/*' -not -path '*/.git/*' \
              2>/dev/null)
done
scan_spinner_stop
