# Go module 下载缓存 (~/go/pkg)
# 这是"重型可选"——清完所有 Go 项目下次构建都要重新拉依赖，且 ~/go/pkg 的 du 通常 30s+

scan_step "Go modcache (慢, 可能 40s+)"
k=$(dir_kb "$HOME/go/pkg")
if (( k > 0 )); then
  add_item "重型可选 ⚠" "$k" "Go module 下载缓存 (所有 Go 项目需重下依赖)" \
    'chmod -R u+w "$HOME/go/pkg" 2>/dev/null; go clean -modcache 2>/dev/null; true'
fi
