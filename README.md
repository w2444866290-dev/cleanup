# cleanup-disk

> macOS 交互式磁盘清理工具：一次扫描 → tabs + 分页多选 → 二次确认 → 一次执行。

```
================================================================
磁盘清理 — 选择要清理的项
[开发工具缓存(3)] [应用缓存(3)] [应用数据 (慎清)(2)] [GVM 旧 Go 版本(6)] [超大 App (≥500MB)(15)]
================================================================

▶ [ ]  [   2.6G]  gopls / goimports 缓存
  [✓]  [   2.4G]  npm 缓存 (~/.npm)
  [ ]  [   2.8G]  Yarn 缓存

────────────────────────────── 共 3 项 ──────────────────────────────

  [ 开始清理 ➜ 已选 1 项, 预估上限 2.4G ]

← → 切 tab   ↑↓ 移动/翻页 (↓ 到底进入按钮)   Space/Enter 勾选   a 全选当前tab   s safe   c 清空   q 退出
```

## 快速开始

```bash
# 直接运行
~/cleanup-disk/cleanup-disk.sh

# 或加 alias (~/.zshrc)
alias cleanup="~/cleanup-disk/cleanup-disk.sh"
```

加完 alias 后 `source ~/.zshrc` 或新开终端，敲 `cleanup` 启动。

## 项目结构

```
cleanup-disk/
├── README.md
├── cleanup-disk.sh         # 入口：source 各模块，串起整个流程
│
├── lib/                    # 公共库（无业务，纯基础设施）
│   ├── ui.sh              # 颜色 + header/note/ok/warn/err + human_kb + print_disk_status
│   ├── progress.sh        # scan_step (同步进度) + spinner (异步进度)
│   ├── items.sh           # 数据数组 CATS/SIZES_KB/DESCS/CMDS + add_item + dir_kb/dirs_kb
│   ├── tui.sh             # TUI 状态机：tabs + 分页列表 + 焦点切换 + 二次确认
│   └── exec.sh            # 执行循环（subshell 隔离） + 完成报告
│
└── scanners/               # 每类清理一个独立文件，sourced 时调用 add_item 注册项目
    ├── 01-system-junk.sh   # 废纸篓 / 崩溃日志 / Homebrew 下载缓存
    ├── 02-mounted-dmg.sh   # 已挂载的安装 DMG
    ├── 03-dev-caches.sh    # Go build / gopls / npm / yarn / pnpm / Xcode / Simulator
    ├── 04-app-caches.sh    # JetBrains / Chrome / Lark / Codex
    ├── 05-careful-data.sh  # 壁纸缓存 / 壁纸代理 / QQ音乐缓存
    ├── 06-go-modcache.sh   # ~/go/pkg（重型，清完所有 Go 项目需重下依赖）
    ├── 07-gvm-versions.sh  # GVM 各旧 Go 版本（按版本独立成项）
    ├── 08-old-large-files.sh # ~/Downloads ~/Documents 等中 ≥100MB 且 180 天未访问的文件
    ├── 09-unused-apps.sh   # 180 天未启动的 App
    └── 10-large-apps.sh    # ≥500MB 的 App
```

## 分层与职责

```
                  ┌─────────────────────────┐
                  │      cleanup-disk.sh    │  入口编排
                  │  (source 各 lib + scan) │
                  └────────────┬────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       │                       │                       │
       ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐        ┌──────────────┐
│   lib/ui.sh  │       │ lib/progress │        │  lib/items   │  ─── 基础设施层
│ 颜色/输出    │       │ scan + spinner│        │ 数据 + add_item│
└──────┬───────┘       └──────┬───────┘        └──────┬───────┘
       │                       │                       │
       └───────────────────────┼───────────────────────┘
                               │
                               ▼
                  ┌────────────────────────┐
                  │     scanners/*.sh      │  ─── 业务层（每类独立）
                  │ scan_step + dir_kb +    │
                  │ add_item 注册项目        │
                  └────────────┬────────────┘
                               │
                  扫描结束后所有项已写入 CATS/SIZES_KB/...
                               │
                  ┌────────────▼────────────┐
                  │       lib/tui.sh        │  ─── 交互层
                  │ tabs + 分页 + 多选       │
                  │ 二次确认 → SELECTED[]   │
                  └────────────┬────────────┘
                               │
                  ┌────────────▼────────────┐
                  │       lib/exec.sh       │  ─── 执行层
                  │ 逐项 eval CMDS[] +       │
                  │ 完成报告                  │
                  └─────────────────────────┘
```

| 层 | 文件 | 职责 | 输入 | 输出 |
|---|---|---|---|---|
| 基础设施 | `lib/ui.sh` | 颜色 / 标题 / 单行状态 / 磁盘 readout | — | 纯函数和常量 |
| 基础设施 | `lib/progress.sh` | 同步/异步进度显示 | `SCAN_TOTAL` | 在 `/dev/tty` 上刷新 |
| 基础设施 | `lib/items.sh` | 清理项数据模型 + 大小测量 | — | `CATS[]`/`SIZES_KB[]`/`SIZES[]`/`DESCS[]`/`CMDS[]` 平行数组 |
| 业务 | `scanners/*.sh` | 各分类的具体扫描逻辑 | 基础设施函数 | `add_item` 调用，向上述数组追加 |
| 交互 | `lib/tui.sh` | tabs + 分页 + 多选 + 二次确认 | 上述平行数组 | `SELECTED[]`（1-based 编号），或 `exit 0`（取消） |
| 执行 | `lib/exec.sh` | 逐项 `eval CMDS[]` + 完成报告 | `SELECTED[]` | stdout 进度行 |

**所有 lib 与 scanners 都是 sourced 进入口脚本**，共享同一 bash 进程的变量空间。这是有意为之：

1. bash 3.2 没有命名空间/模块系统，sourcing 是事实标准
2. 平行数组 + 全局状态对 36 项规模来说足够，避免引入对象抽象的复杂度
3. 子进程只用在 `lib/progress.sh` 的 spinner（后台异步）和 `lib/exec.sh` 的执行 subshell（隔离）

## 添加一个新的清理分类

只需新增一个 `scanners/NN-<name>.sh`（NN 是两位前缀，决定 tab 顺序）：

```bash
# scanners/11-my-new-category.sh

scan_step "我的新缓存"
k=$(dir_kb "$HOME/Library/Caches/com.example.thing")
add_item "我的新分类" "$k" "Example 缓存 (重启后重建)" \
  'rm -rf "$HOME/Library/Caches/com.example.thing/"* 2>/dev/null; true'
```

记得调整 `cleanup-disk.sh` 顶部的 `SCAN_TOTAL` 估算（按你新增的 `scan_step` 调用数加上去），并在 `lib/tui.sh` 的 `is_safe_cat` 函数中决定这个分类是否归入 `s` 预设。

## 关键设计点

### 平行数组而非对象

每个清理项的 5 个属性（分类、大小 KB、大小展示、描述、清理命令）放在 5 个平行数组的同一下标。优势：

- bash 3.2 完全兼容（无需关联数组）
- 排序、求和、过滤都是简单循环
- 数据驱动 —— TUI 不需要知道 scanner 业务

### `add_item` 的 100KB 过滤

`go clean -cache` 清完会留 `README` + `trim.txt` 共约 8K 元数据。`add_item` 跳过 < 100KB 的项目，下次跑就不再骚扰用户。

### `eval` 的安全隔离

每条清理命令在 subshell 中执行：

```bash
if ( set +u; eval "${CMDS[$idx]}" ) </dev/null; then
```

- `set +u`：避免 `source ~/.gvm/scripts/gvm` 之类外部脚本展开未定义变量时让父脚本退出
- `</dev/null`：防 `gvm uninstall`/`osascript` 等读 stdin 阻塞
- `( ... )` 子 shell：即使被 source 的脚本里有 `exit`，也只杀 subshell

### Alt screen + 状态机

TUI 在 alt screen 上运行（`tput smcup`），退出时先 `\033[2J\033[H\033[3J` 把 alt screen 内容清空再 `rmcup`，避免某些终端把 alt screen 残留 echo 到主 scrollback。

状态机两态：

| 状态 | 显示 | 主要键 |
|---|---|---|
| `select` | tabs + 分页列表 + 开始清理按钮 | `←→` 切 tab、`↑↓` 移动/进入按钮、`Space/Enter` 勾选、`s/a/c` 预设、`Enter` 在按钮上进入 confirm |
| `confirm` | 选中项列表 + 总大小 + [返回修改]/[开始清理] | `←→` 切按钮、`Enter` 确认、`Esc` 返回 |

UI 设计资料在 [docs/ui/](docs/ui/) —— 见目录里的 [README](docs/ui/README.md)：含 `ui.md` 设计规范、可在浏览器打开的视觉对照页，以及配套 jsx。

## 已知限制

- **`du` 不识别 APFS clone / 硬链接的共享空间**：GVM 多个 Go 版本之间常有共享 block，预估"上限"会偏高（这就是 UI 上写"预估上限"而非"预计释放"的原因）。
- **移到废纸篓 ≠ 真正释放**：旧大文件、不常用 App、超大 App 都走 Finder 移废纸篓（可恢复），要去 Finder 清空才真正释放。
- **终端宽度 < 120 字符**：tabs 一行可能 wrap，视觉略乱但功能正常。
- **bash 3.2 兼容**：未使用关联数组、`mapfile` 等 bash 4+ 特性。

## 卸载

```bash
rm -rf ~/cleanup-disk
# 然后从 ~/.zshrc 删掉 alias 那行
```

废纸篓里的东西按需手动清空。
