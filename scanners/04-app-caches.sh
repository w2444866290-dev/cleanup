# 应用缓存：JetBrains / Chrome / Lark / Codex 在 ~/Library/Caches/ 下的子目录
# 都是会被应用自动重建的缓存，与用户数据（聊天记录/书签/登录态）分离

scan_step "JetBrains 缓存"
k=$(dir_kb "$HOME/Library/Caches/JetBrains")
add_item "应用缓存" "$k" "JetBrains 缓存 (IDE 会重建索引)" \
  'rm -rf "$HOME/Library/Caches/JetBrains/"* 2>/dev/null; true'

scan_step "Chrome 缓存"
k=$(dir_kb "$HOME/Library/Caches/Google")
add_item "应用缓存" "$k" "Chrome / Google 缓存" \
  'rm -rf "$HOME/Library/Caches/Google/"* 2>/dev/null; true'

scan_step "Lark 缓存"
k=$(dir_kb "$HOME/Library/Caches/LarkShell")
add_item "应用缓存" "$k" "Lark / 飞书 缓存" \
  'rm -rf "$HOME/Library/Caches/LarkShell/"* 2>/dev/null; true'

scan_step "Codex 缓存"
k=$(dir_kb "$HOME/Library/Caches/com.openai.codex")
add_item "应用缓存" "$k" "OpenAI Codex 缓存" \
  'rm -rf "$HOME/Library/Caches/com.openai.codex/"* 2>/dev/null; true'
