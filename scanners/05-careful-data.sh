# 应用数据 (慎清)：壁纸缓存 / 壁纸代理 / QQ音乐缓存
# 名字里就告诉用户"慎清"——这些虽然安全，但放在 Application Support / Containers 下，
# 比纯 Caches/ 更接近"应用数据"区，列入 safe 预设会让用户误以为是无脑可清

scan_step "壁纸缓存"
k=$(dir_kb "$HOME/Library/Application Support/com.apple.wallpaper")
add_item "应用数据 (慎清)" "$k" "壁纸缓存 (macOS 自动重建)" \
  'rm -rf "$HOME/Library/Application Support/com.apple.wallpaper/"* 2>/dev/null; true'

scan_step "壁纸代理"
k=$(dir_kb "$HOME/Library/Containers/com.apple.wallpaper.agent")
add_item "应用数据 (慎清)" "$k" "壁纸代理 com.apple.wallpaper.agent" \
  'rm -rf "$HOME/Library/Containers/com.apple.wallpaper.agent" 2>/dev/null; true'

scan_step "QQ音乐缓存"
k=$(dir_kb "$HOME/Library/Containers/com.tencent.QQMusicMac/Data/Library/Caches")
add_item "应用数据 (慎清)" "$k" "QQ音乐缓存 (歌曲会重新下载)" \
  'rm -rf "$HOME/Library/Containers/com.tencent.QQMusicMac/Data/Library/Caches/"* 2>/dev/null; true'
