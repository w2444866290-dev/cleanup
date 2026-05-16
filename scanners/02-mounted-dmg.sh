# 已挂载的安装 DMG：扫 /Volumes/ 下挂载点，diskutil info 判 Disk Image 类型

scan_step "已挂载安装 DMG"
while IFS=$'\t' read -r vol dev; do
  [[ "$vol" == "/" || "$vol" == "/System"* ]] && continue
  if diskutil info "$dev" 2>/dev/null | grep -q "Disk Image"; then
    k=$(dir_kb "$vol")
    add_item "已挂载安装 DMG" "$k" "$vol" \
      "hdiutil detach \"$vol\" -quiet 2>/dev/null; true"
  fi
done < <(mount | sed -nE 's#^([^ ]+) on (.+) \([^)]+\)$#\2\t\1#p')
