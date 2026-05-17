# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 这是什么

macOS 交互式磁盘清理 CLI（bash 实现）。一次扫描 → tabs 多选 TUI → 二次确认 → 一次执行。入口是 `cleanup-disk.sh`，其余文件全部 `source` 进同一个 bash 进程。

## 运行

```bash
./cleanup-disk.sh          # 进入 alt-screen TUI，交互式运行
```

没有 build、没有测试套件、没有 lint 配置，也没有 CI。README 里只是给最终用户记录了 `alias cleanup="~/cleanup-disk/cleanup-disk.sh"` 的安装方式。

调试 TUI 渲染时注意：脚本会进入终端的 alt screen（`tput smcup`）并直接从 stdin 读按键 —— **没法用管道或后台跑来测**，只能在真实终端里跑。

## 架构

五层，全部 source 到同一个 bash 进程里；模块之间通过共享全局变量通信（函数不返回数据，而是改写平行数组）。

```
cleanup-disk.sh    # 入口：依次 source lib/* → scanners/* → tui → exec
  ├── lib/ui.sh         # 颜色、字符常量、_paint/_vwidth/_lpad_to 等渲染工具、human_kb、print_disk_status
  ├── lib/progress.sh   # scan_step（同步进度条）+ spinner_start/stop（异步，写 /dev/tty）
  ├── lib/items.sh      # add_item、dir_kb、dirs_kb，以及那 5 个平行数组
  ├── scanners/NN-*.sh  # 业务逻辑：每个文件调用 scan_step + add_item
  ├── lib/tui.sh        # tabs + 分页列表 + 二次确认 → SEL_FLAGS、SELECTED
  └── lib/exec.sh       # 在 subshell 里 eval CMDS[i] + 末尾报告
```

**数据模型是 5 个平行数组**，同下标对齐：`CATS[i]`、`SIZES_KB[i]`、`SIZES[i]`、`DESCS[i]`、`CMDS[i]`。scanner 通过 `add_item` 追加，TUI 读这些数组，exec 执行 `eval "${CMDS[i]}"`。这是有意为之 —— bash 3.2 没有关联数组、没有模块系统，sourcing + 平行数组就是本项目的惯用法。**不要在它上面再叠抽象。**

**scanner 顺序 = tab 顺序。** `cleanup-disk.sh` 用 `scanners/[0-9]*.sh` 通配遍历，文件名 `NN-` 前缀直接决定 TUI 中 tab 的左→右顺序。tab 列表在 `lib/tui.sh:build_tabs` 里通过遍历 `CATS` 按出现顺序去重生成。

**`add_item` 会丢弃 < 100 KB 的项。** 这是刻意的 —— 比如 `go clean -cache` 清完后剩几 KB 元数据；没有这个阈值，用户每次跑都会看到"已清理"的项目又冒出来。

**执行隔离**（`lib/exec.sh`）：每条清理命令以 `( set +u; eval "${CMDS[idx]}" ) </dev/null` 方式运行。subshell + `set +u` + `</dev/null` 三件套都是承重的 —— 看代码里的内联注释。具体来说：`source ~/.gvm/scripts/gvm` 引用未定义变量（`set -u` 下会杀掉父进程）；`gvm uninstall` / `osascript` 可能读 stdin；某些被 source 的脚本里有 `exit`。**新增 scanner 时不要改这个模式。**

**SCAN_TOTAL 是人工维护的估算**，位于 `cleanup-disk.sh`，用来估算总共会调用多少次 `scan_step`，仅供进度条计算百分比。在 scanner 里增删 `scan_step` 调用时，要同步调整 `SCAN_TOTAL` 块里对应那一行的累加。如果估算偏小，`scan_step` 内部会自动把 total 抬到 `SCAN_STEP`，进度条仍能跑满，只是中途百分比不准。

**TUI 状态机**（`lib/tui.sh`）：两个状态。
- `select`：tabs + 分页列表（PAGE_SIZE=7）+ 开始清理按钮。`FOCUS=list|button` —— 列表最后一项再按 `↓` 焦点跳到按钮。
- `confirm`：按分类列出选中项，默认焦点在 `[ 开始清理 ]`。

输出用裸 ANSI 转义（`\033[2J\033[H` 等），没有 curses 依赖。退出时 `restore_tui` 先清空 alt screen 内容，**再** `rmcup` —— 因为某些终端会在 `rmcup` 时把 alt screen 残留回显一份到主 scrollback。

**`s`（safe）预设**由 `lib/tui.sh:is_safe_cat` 定义，是一个**排除**列表：列在里面的分类被排除在 safe 默认之外。新增一个会触及用户数据 / 比缓存重建更具破坏性的分类时，记得把它加进那个 case 语句。

## 添加一个 scanner

新建 `scanners/NN-<name>.sh`（两位数前缀决定 tab 位置）：

```bash
scan_step "<spinner 旁的短标签>"
k=$(dir_kb "$HOME/Library/Caches/com.example.thing")
add_item "<分类名 / tab 名>" "$k" "<列表里显示的描述>" \
  'rm -rf "$HOME/Library/Caches/com.example.thing/"* 2>/dev/null; true'
```

清单：
1. 每个 `scan_step` 调用都应该在 `cleanup-disk.sh` 的 `SCAN_TOTAL` 块里有对应的累加项。
2. 清理命令结尾加 `; true`，防止 `rm` 的非零返回污染 exec 层的成功/失败计数。
3. 如果新分类有破坏性 / 触及用户数据，记得在 `lib/tui.sh:is_safe_cat` 中把它加入排除列表。
4. 清理命令会被 `eval` —— 用单引号包裹，让 `$HOME` / 其他变量在 exec 阶段展开（看 `07-gvm-versions.sh` 的写法：内层用 `\$HOME` 转义、而 `$_ver` 在 scan 阶段就要展开，所以外层用了双引号 + 内层 `\$` 的混合方案）。

## bash 3.2 兼容

macOS 自带 bash 3.2，**不要**引入：
- 关联数组（`declare -A`）
- `mapfile` / `readarray`
- `${var,,}` / `${var^^}` 大小写变换
- `&>` 重定向（用 `>... 2>&1`）

代码库刻意守在 bash 3.2 边界内 —— 因为 macOS 的 `/bin/bash` 就是 3.2，用户不一定装了更新的 bash。

## 一些"看着像 bug、其实是设计"的细节

- **`du` 把 APFS clone / 硬链接的共享空间重复计算了。** UI 写的是"预估上限"而不是"将释放" —— GVM 多个 Go 版本之间常有共享 block，逐版本 `du` 加总会超出真实值。**不要尝试"修正"它**，UI 上的措辞本身就是规避方案。
- **"移到废纸篓" ≠ 真正释放。** old-large-files / unused-apps / large-apps 三个 scanner 都是通过 `osascript` 走 Finder 移到废纸篓。结尾报告里"本次释放"读的是 `df`，可能要等用户清空废纸篓才会变 —— 这是预期行为；末尾那行提示就是为此存在的。
- **`${#var}` 对中文字符串返回字节数，不是显示列数。** `lib/tui.sh:draw_footer_line` 用 `bytes * 2/3` 的启发式做居中。任何依赖字符串宽度做布局的地方都要小心这个坑。
