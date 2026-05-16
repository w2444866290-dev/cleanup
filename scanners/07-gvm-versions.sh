# GVM 旧 Go 版本：每个非活跃 Go 版本作为独立项，大小 = gos/<ver> + pkgsets/<ver>
# 卸载命令优先用 gvm uninstall（同时清 environments），失败回退到 rm -rf

if [[ -d "$HOME/.gvm/gos" ]]; then
  # 当前活跃版本：通过 go env GOROOT (如 ~/.gvm/gos/go1.24)
  CURRENT_VER=""
  _goroot=$(go env GOROOT 2>/dev/null)
  if [[ "$_goroot" == "$HOME/.gvm/gos/"* ]]; then
    CURRENT_VER="${_goroot#$HOME/.gvm/gos/}"
  fi
  for _ver_dir in "$HOME/.gvm/gos/"*/; do
    [[ -d "$_ver_dir" ]] || continue
    _ver="$(basename "$_ver_dir")"
    # 跳过系统版本、gvm 引导版本、当前活跃版本
    case "$_ver" in
      system|go1.4) continue ;;
    esac
    [[ -n "$CURRENT_VER" && "$_ver" == "$CURRENT_VER" ]] && continue
    scan_step "gvm $_ver"
    k1=$(dir_kb "$HOME/.gvm/gos/$_ver")
    k2=$(dir_kb "$HOME/.gvm/pkgsets/$_ver")
    total_k=$(( k1 + k2 ))
    add_item "GVM 旧 Go 版本" "$total_k" \
      "${_ver}  ${C_DIM}— gos+pkgsets, 用 gvm uninstall 卸载${C_RESET}" \
      "source \"\$HOME/.gvm/scripts/gvm\" 2>/dev/null && gvm uninstall \"$_ver\" >/dev/null 2>&1 || { rm -rf \"\$HOME/.gvm/gos/$_ver\" \"\$HOME/.gvm/pkgsets/$_ver\" 2>/dev/null; }; true"
  done
fi
