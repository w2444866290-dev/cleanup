# 开发工具缓存：Go build / gopls / npm / yarn / pnpm / Xcode / iOS Simulator
# 清完后下次构建会自动重建，不影响项目本身

if command -v go >/dev/null 2>&1; then
  scan_step "Go 构建缓存"
  k=$(dir_kb "$HOME/Library/Caches/go-build")
  add_item "开发工具缓存" "$k" "Go 构建缓存 (go clean -cache)" \
    'go clean -cache 2>/dev/null; true'
fi

scan_step "gopls / goimports"
k=$(dirs_kb "$HOME/Library/Caches/gopls" "$HOME/Library/Caches/goimports")
add_item "开发工具缓存" "$k" "gopls / goimports 缓存" \
  'rm -rf "$HOME/Library/Caches/gopls" "$HOME/Library/Caches/goimports" 2>/dev/null; true'

if command -v npm >/dev/null 2>&1; then
  scan_step "npm 缓存"
  k=$(dir_kb "$HOME/.npm")
  add_item "开发工具缓存" "$k" "npm 缓存 (~/.npm)" \
    'npm cache clean --force >/dev/null 2>&1; true'
fi

if command -v yarn >/dev/null 2>&1; then
  scan_step "Yarn 缓存"
  k=$(dir_kb "$HOME/Library/Caches/Yarn")
  add_item "开发工具缓存" "$k" "Yarn 缓存" \
    'yarn cache clean >/dev/null 2>&1; true'
fi

if command -v pnpm >/dev/null 2>&1; then
  scan_step "pnpm store"
  ps=$(pnpm store path 2>/dev/null)
  if [[ -n "$ps" && -d "$ps" ]]; then
    k=$(dir_kb "$ps")
    add_item "开发工具缓存" "$k" "pnpm store" \
      'pnpm store prune >/dev/null 2>&1; true'
  fi
fi

scan_step "Xcode DerivedData"
k=$(dir_kb "$HOME/Library/Developer/Xcode/DerivedData")
add_item "开发工具缓存" "$k" "Xcode DerivedData" \
  'rm -rf "$HOME/Library/Developer/Xcode/DerivedData/"* 2>/dev/null; true'

scan_step "iOS Simulator 缓存"
k=$(dir_kb "$HOME/Library/Developer/CoreSimulator/Caches")
add_item "开发工具缓存" "$k" "iOS Simulator 缓存" \
  'rm -rf "$HOME/Library/Developer/CoreSimulator/Caches/"* 2>/dev/null; true'
