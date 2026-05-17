# cleanup-disk · Whisper UI 设计 (zh-CN)

中文母语版 CLI 设计：每屏开头是动作 / 状态短句（不带统一 header），磁盘读数句子化，无横线装饰，按钮回到 `[ 开始清理 ]` 中文 CLI 惯例。视觉参考 `Whisper - Refined.html` 中「完整状态图 · v4 (中文母语版)」那一栏。

---

## 0. 通用样式构件

### 0.1 颜色检测 & 常量

`isatty(stdout)` 且 `TERM != dumb` 且 `tput colors ≥ 256` 时启用 256 色，否则降级到 8 色；非 TTY 输出全为空字符串（保留可读纯文本）。

```bash
if [[ -t 1 ]]; then
  if [[ "${TERM:-}" != "dumb" ]] && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]]; then
    C_FG="$(printf '\033[38;5;253m')"
    C_FAINT="$(printf '\033[38;5;243m')"
    C_GREEN="$(printf '\033[38;5;108m')"
    C_YELLOW="$(printf '\033[38;5;179m')"
    C_RED="$(printf '\033[38;5;167m')"
    C_CYAN="$(printf '\033[38;5;108m')"
    C_BLUE="$(printf '\033[38;5;109m')"
  else
    C_FG=""
    C_FAINT="$(printf '\033[2m')"
    C_GREEN="$(printf '\033[32m')"
    C_YELLOW="$(printf '\033[33m')"
    C_RED="$(printf '\033[31m')"
    C_CYAN="$(printf '\033[36m')"
    C_BLUE="$(printf '\033[34m')"
  fi
  C_DIM="$(printf '\033[2m')"
  C_BOLD="$(printf '\033[1m')"
  C_RESET="$(printf '\033[0m')"
else
  C_FG="" C_FAINT="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN="" C_BLUE=""
  C_DIM="" C_BOLD="" C_RESET=""
fi
```

### 0.2 字符常量

```bash
G_CURSOR="▸"
G_BOX_EMPTY="◯"
G_BOX_FULL="●"
G_KICKER_SEP="·"          # 仅 confirm 分类项目符还用到
G_CAT_BULLET="·"
G_BAR_FILL="━"
G_BAR_EMPTY="━"
G_OK="✓"
G_FAIL="✗"
G_WARN="!"
G_ELLIPSIS="…"
G_ARROW_UP="↑"
G_ARROW_DOWN="↓"
G_SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
```

### 0.3 布局常量

```bash
LAYOUT_WIDTH=64
LAYOUT_GUTTER=2
LAYOUT_BAR_WIDTH=49
LAYOUT_LIST_MAX=7
```

### 0.4 工具函数

| 函数 | 签名 | 用途 |
|---|---|---|
| `_repeat` | `_repeat CHAR N` | 重复字符 N 次 |
| `nl` | `nl [N=1]` | 打 N 行空行 |
| `_vwidth` | `_vwidth STR` | 字符串的终端显示列宽（CJK 全宽算 2 列；剥 ANSI；bash 3.2 兼容 UTF-8 解码）|
| `_lpad_to` | `_lpad_to STR W` | 左对齐填充到 W 列（不截断）|
| `_rpad_to` | `_rpad_to STR W` | 右对齐填充到 W 列 |
| `_paint` | `_paint TEXT COLOR` | 输出 `${COLOR}${TEXT}${C_RESET}`，让色彩拼接顺手 |

`_paint` 实现：

```bash
_paint() {
  printf '%s%s%s' "$2" "$1" "$C_RESET"
}
```

`_vwidth` 在 bash 3.2 下是承重函数 —— 所有中文列对齐 / 居中都依赖它。

### 0.5 句子化 disk strip · `print_disk_status`

```bash
print_disk_status() {
  local total used free pct
  read -r total used free pct < <(_df_values)   # "460Gi 326Gi 110Gi 75"
  printf '  '
  _paint "磁盘已用 "          "$C_DIM"
  _paint "${pct}%"            "$C_FG"
  _paint "（"                  "$C_DIM"
  _paint "$used"              "$C_FG"
  _paint "/"                  "$C_DIM"
  _paint "$total"             "$C_FG"
  _paint "），剩余 "           "$C_DIM"
  _paint "$free"              "$C_BOLD$C_GREEN"
  printf '\n'
}
```

输出：

```
  磁盘已用 75%（326Gi/460Gi），剩余 110Gi
```

> 标签 `磁盘已用 / 剩余 / 括号 / 斜杠` 全 `DIM`；数值 `FG`；`剩余` 的数值 `BOLD GREEN`（最显眼的那一个）。

### 0.6 设计原则：每屏自己开篇

每屏开头是这屏特有的动作 / 状态短句，**第一行就直接传达"现在发生了什么"**。无统一标题栏，无横线装饰，无 kicker。具体见 §1–§5。

---

## 1. 扫描阶段

### 1.1 启动 · `scan_init`

```bash
scan_init() {
  printf '  '
  _paint "正在扫描可清理项"   "$C_FG"
  _paint "，"                  "$C_DIM"
  _paint "~/go/pkg"           "$C_FG"
  _paint " 较大，预计需要 ~40 秒" "$C_DIM"
  printf '\n'
  nl 1
  print_disk_status
}
```

输出：

```
  正在扫描可清理项，~/go/pkg 较大，预计需要 ~40 秒

  磁盘已用 75%（326Gi/460Gi），剩余 110Gi
```

### 1.2 进度条 · `scan_step`

第一行：动作 + 右对齐百分比；第二行：bar。

```bash
scan_step() {
  local cur=$SCAN_STEP total=$SCAN_TOTAL
  local pct=$(( cur * 100 / total ))
  local filled=$(( cur * LAYOUT_BAR_WIDTH / total ))
  local empty=$(( LAYOUT_BAR_WIDTH - filled ))

  local pct_str; pct_str=$(printf '%d%%' "$pct")
  local left="正在扫描 ${cur}/${total} 项…"
  local left_w; left_w=$(_vwidth "$left")
  local pct_w; pct_w=$(_vwidth "$pct_str")
  local mid_pad=$(( LAYOUT_WIDTH - left_w - pct_w )); (( mid_pad < 1 )) && mid_pad=1

  printf '\r\033[K  '
  _paint "正在扫描 "          "$C_FG"
  _paint "${cur}/${total}"     "$C_FAINT"
  _paint " 项…"                "$C_FG"
  printf '%*s' "$mid_pad" ""
  _paint "$pct_str"            "$C_FG"
  printf '\n'

  printf '\033[K  '
  _paint "$(_repeat "$G_BAR_FILL"  "$filled")" "$C_GREEN"
  _paint "$(_repeat "$G_BAR_EMPTY" "$empty")"  "$C_DIM"
  printf '\n'

  printf '\033[2A'
}
```

输出（`cur=18, total=29`）：

```
  正在扫描 18/29 项…                                        62%
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╴━━━━━━━━━━━━━━━━━━━━━━
```

### 1.3 慢项 spinner · `scan_spinner_*`

慢项启动的异步 spinner，写 `/dev/tty`，避开主输出。spinner 行右端显示「已用 NNs」，且仅在 `elapsed ≥ 2s` 才出现（短任务不闪）：

```bash
scan_spinner_tick() {
  local now=$(date +%s)
  local elapsed=$(( now - SPINNER_START_TS ))
  (( elapsed < 2 )) && return

  local glyph=${G_SPINNER[$(( SPINNER_IDX % 10 ))]}
  SPINNER_IDX=$(( SPINNER_IDX + 1 ))

  # 路径字段 = 64 - 2(gutter) - 1(spinner) - 2(sep) - 7(右端 "已用 NNs" 含前导空) = 52
  local path_w; path_w=$(_vwidth "$SPINNER_PATH")
  local pad=$(( 52 - path_w )); (( pad < 1 )) && pad=1

  printf '\033[s\033[2B\r\033[K  '
  _paint "$glyph"               "$C_CYAN"
  printf '  '
  _paint "$SPINNER_PATH"        "$C_DIM"
  printf '%*s' "$pad" ""
  _paint "已用 "                 "$C_DIM"
  _paint "${elapsed}s"           "$C_YELLOW"
  printf '\033[u' >/dev/tty
}
```

输出：

```
  ⣷  ~/go/pkg                                          已用 15s
```

`scan_spinner_start` 起后台循环 tick；`scan_spinner_stop` 终止并清空 spinner 行。

### 1.4 `scan_done`

进 alt screen 前调用，清掉之前留下的 3 行（动作 + bar + spinner 残痕）。

---

## 2. 主菜单（`STATE=select`）

### 2.0 整体流水

```bash
render_select() {
  clear
  print_disk_status                # 第一行就是 disk strip，无 kicker
  nl 1
  render_tabs_line
  nl 1
  render_list_overflow_top
  render_list
  render_list_overflow_bottom
  nl 1
  render_count_line
  nl 1
  render_clean_button
  nl 2
  render_keys_select
}
```

### 2.1 Tabs · `render_tabs_line`

```bash
# globals: TAB_NAMES TAB_COUNTS TAB_CUR
render_tabs_line() {
  local i name count label len
  local out_text="  "
  local out_underline="  "
  for i in "${!TAB_NAMES[@]}"; do
    name="${TAB_NAMES[i]}"
    count="${TAB_COUNTS[i]}"
    label="${name}（${count}）"
    len=$(_vwidth "$label")
    if (( i == TAB_CUR )); then
      out_text+="${C_BOLD}${C_GREEN}${label}${C_RESET}"
      out_underline+="${C_GREEN}$(_repeat "─" "$len")${C_RESET}"
    else
      out_text+="${C_DIM}${label}${C_RESET}"
      out_underline+="$(printf '%*s' "$len" "")"
    fi
    if (( i < ${#TAB_NAMES[@]} - 1 )); then
      out_text+="   "
      out_underline+="   "
    fi
  done
  printf '%s\n%s\n' "$out_text" "$out_underline"
}
```

输出（首 tab 选中）：

```
  开发工具缓存（3）   应用缓存（3）   应用数据（2）   重型可选（1）   GVM（6）   …
  ────────────────
```

> 计数用全角括号 `（N）`；tab 间 3 空格分隔；当前 tab 下有等宽绿色 `─` 下划线（含括号一并算长度）。

### 2.2 列表行 · `render_list`

行格式：`cursor(1) + 3sp + check(1) + 3sp + size(6 右对齐) + 5sp + desc`。

```bash
render_list() {
  local i row checked size desc cursor_str check_str
  for i in "${!LIST_VIEW[@]}"; do
    IFS='|' read -r checked size desc <<<"${LIST_VIEW[i]}"
    if (( i == CURSOR_ROW )) && [[ "$FOCUS" == "list" ]]; then
      cursor_str="${C_BOLD}${C_GREEN}${G_CURSOR}${C_RESET}"
    else
      cursor_str=" "
    fi
    if [[ "$checked" == "1" ]]; then
      check_str="${C_GREEN}${G_BOX_FULL}${C_RESET}"
    else
      check_str="${C_DIM}${G_BOX_EMPTY}${C_RESET}"
    fi
    printf '  %s   %s   %s%6s%s     %s\n' \
      "$cursor_str" "$check_str" \
      "$C_YELLOW" "$size" "$C_RESET" \
      "$desc"
  done
}
```

### 2.3 列表上下省略 · `render_list_overflow_top / _bottom`

```bash
render_list_overflow_top() {
  if (( LIST_OFFSET > 0 )); then
    printf '  %s%s还有 %d 项 %s%s\n' \
      "$C_DIM" "$G_ELLIPSIS" "$LIST_OFFSET" "$G_ARROW_UP" "$C_RESET"
  else
    printf '\n'
  fi
}

render_list_overflow_bottom() {
  local hidden_below=$(( LIST_TOTAL - LIST_OFFSET - ${#LIST_VIEW[@]} ))
  if (( hidden_below > 0 )); then
    printf '  %s%s还有 %d 项 %s%s\n' \
      "$C_DIM" "$G_ELLIPSIS" "$hidden_below" "$G_ARROW_DOWN" "$C_RESET"
  else
    printf '\n'
  fi
}
```

> 即使没有 overflow 也要打一行空行占位 —— 列表上下各保留 1 行槽位，UI 高度稳定。

### 2.4 计数行 · `render_count_line`

```bash
render_count_line() {
  printf '  %s共 %d 项%s\n' "$C_DIM" "$LIST_TOTAL" "$C_RESET"
}
```

无横线。输出：

```
  共 3 项
```

### 2.5 「开始清理」按钮 · `render_clean_button`

```bash
# Args: $1 = 已选数, $2 = 总大小（如 "2.8G"，未选时给空串）
render_clean_button() {
  local n=$1 total=$2 cursor body

  if [[ "$FOCUS" == "button" ]]; then
    cursor="  ${C_BOLD}${C_GREEN}${G_CURSOR}${C_RESET}   "
  else
    cursor="      "
  fi

  if (( n == 0 )); then
    body="${C_DIM}[ 开始清理 ]   未选项${C_RESET}"
  else
    if [[ "$FOCUS" == "button" ]]; then
      body="${C_BOLD}${C_GREEN}[ 开始清理 ]   已选 ${n} 项，${total}${C_RESET}"
    else
      body="${C_BOLD}${C_GREEN}[ 开始清理 ]${C_RESET}   ${C_FG}已选 ${n} 项${C_RESET}${C_DIM}，${C_RESET}${C_YELLOW}${total}${C_RESET}"
    fi
  fi
  printf '%s%s\n' "$cursor" "$body"
}
```

四态对照：

```
未选 · 焦点列表        [ 开始清理 ]   未选项                 （全 DIM）
未选 · 焦点按钮     ▸  [ 开始清理 ]   未选项                 （cursor 绿 BOLD，余 DIM）
已选 · 焦点列表        [ 开始清理 ]   已选 5 项，30.5G       （[ ] 加 verb 绿，info 默认 + 黄数值）
已选 · 焦点按钮     ▸  [ 开始清理 ]   已选 5 项，30.5G       （全部绿 BOLD）
```

### 2.6 Keys hint · `render_keys_select`

```bash
render_keys_select() {
  printf '  %s← → 切 tab    ↑↓ 移动    空格 勾选    a 全选    s safe    c 清空    q 退出%s\n' \
    "$C_DIM" "$C_RESET"
}
```

### 2.7 空状态 · `render_empty`

```bash
render_empty() {
  nl 1
  printf '  '
  _paint "${G_OK} " "$C_BOLD$C_GREEN"
  _paint "磁盘已经很干净了，没有需要清理的项目。" "$C_FG"
  printf '\n'
  nl 1
  print_disk_status
}
```

输出：

```
  ✓ 磁盘已经很干净了，没有需要清理的项目。

  磁盘已用 53%（244Gi/460Gi），剩余 216Gi
```

> 不进 alt screen；打完直接 `exit 0`。

---

## 3. 二次确认（`STATE=confirm`）

### 3.0 整体流水

```bash
render_confirm() {
  clear
  render_confirm_opener            # "以下 N 项将被清理："
  nl 2
  render_confirm_groups
  nl 3
  render_release_banner "$RELEASE_TOTAL"
  nl 3
  render_confirm_buttons
  nl 2
  render_keys_confirm
}
```

### 3.1 开篇 · `render_confirm_opener`

```bash
render_confirm_opener() {
  local n=${#CONFIRM_ITEMS[@]}
  printf '  '
  _paint "以下 "      "$C_FG"
  _paint "${n} 项"    "$C_BOLD$C_GREEN"
  _paint " 将被清理：" "$C_FG"
  printf '\n'
}
```

输出：

```
  以下 3 项 将被清理：
```

### 3.2 分类组 · `render_confirm_groups`

```bash
# CONFIRM_ITEMS row: "category|note|size|desc|desc_note"
render_confirm_groups() {
  local prev_cat="" cat note size desc desc_note
  for row in "${CONFIRM_ITEMS[@]}"; do
    IFS='|' read -r cat note size desc desc_note <<<"$row"
    if [[ "$cat" != "$prev_cat" ]]; then
      [[ -n "$prev_cat" ]] && nl 1
      if [[ -n "$note" ]]; then
        printf '  %s%s  %s%s%s（%s）%s\n' \
          "$C_BOLD$C_CYAN" "$G_CAT_BULLET" "$cat" "$C_RESET" \
          "$C_DIM" "$note" "$C_RESET"
      else
        printf '  %s%s  %s%s\n' "$C_BOLD$C_CYAN" "$G_CAT_BULLET" "$cat" "$C_RESET"
      fi
      prev_cat="$cat"
    fi
    if [[ -n "$desc_note" ]]; then
      printf '       %s%6s%s     %s%s（%s）%s\n' \
        "$C_YELLOW" "$size" "$C_RESET" "$desc" "$C_DIM" "$desc_note" "$C_RESET"
    else
      printf '       %s%6s%s     %s\n' "$C_YELLOW" "$size" "$C_RESET" "$desc"
    fi
  done
}
```

输出：

```
  ·  开发工具缓存
       2.6G     gopls / goimports 缓存

  ·  应用数据（慎清）
       6.7G     壁纸缓存（macOS 自动重建）

  ·  GVM（旧 Go 版本）
      46.2G     go1.16   gos+pkgsets · gvm uninstall
```

> 备注全部用全角括号 `（）`；尺寸右对齐 6 列；描述里出现的英文 / 命令保持原状不翻译。

### 3.3 释放总量 · `render_release_banner`

```bash
render_release_banner() {
  local total=$1
  local plain="预计释放 ${total}"
  local w; w=$(_vwidth "$plain")
  local pad=$(( (LAYOUT_WIDTH - w) / 2 )); (( pad < 0 )) && pad=0

  printf '%*s' "$pad" ""
  _paint "预计释放 "  "$C_FG"
  _paint "$total"     "$C_BOLD$C_GREEN"
  printf '\n'
}
```

输出（前后各空 3 行，由 `render_confirm` 的 `nl 3` 处理）：

```


                           预计释放 55.5 GiB


```

> 无横线、无装饰。靠 `_vwidth` 做居中。

### 3.4 按钮 · `render_confirm_buttons`

```bash
# CONFIRM_BTN ∈ {0,1}  — 0=返回修改, 1=开始清理 (默认 1)
render_confirm_buttons() {
  if (( CONFIRM_BTN == 1 )); then
    printf '       %s[ 返回修改 ]%s          %s%s [ 开始清理 ]%s\n' \
      "$C_DIM" "$C_RESET" \
      "$C_BOLD$C_GREEN" "$G_CURSOR" "$C_RESET"
  else
    printf '     %s%s [ 返回修改 ]%s          %s[ 开始清理 ]%s\n' \
      "$C_BOLD$C_GREEN" "$G_CURSOR" "$C_RESET" \
      "$C_DIM" "$C_RESET"
  fi
}
```

输出（默认焦点在开始清理）：

```
       [ 返回修改 ]          ▸ [ 开始清理 ]
```

### 3.5 Keys hint

```bash
render_keys_confirm() {
  printf '  %s← → 切换    Enter 确认    q 返回%s\n' "$C_DIM" "$C_RESET"
}
```

---

## 4. 执行阶段

```bash
render_exec_init() {
  local total=$1
  printf '  '
  _paint "正在清理 "   "$C_FG"
  _paint "${total} 项" "$C_BOLD$C_GREEN"
  _paint "…"           "$C_FG"
  printf '\n'
  nl 1
}

render_exec_running() {
  local cur=$1 total=$2 desc=$3
  printf '\r\033[K  %s%s%s  %s%d/%d%s  %s%s' \
    "$C_CYAN" "${G_SPINNER[$(( $(date +%s%N | cut -c14-) % 10 ))]}" "$C_RESET" \
    "$C_DIM" "$cur" "$total" "$C_RESET" \
    "$C_FG" "$desc"
}

render_exec_result() {
  local cur=$1 total=$2 desc=$3 rc=$4
  local glyph color
  if (( rc == 0 )); then glyph="$G_OK"; color="$C_GREEN"
  else glyph="$G_FAIL"; color="$C_RED"; FAIL=$(( FAIL + 1 ))
  fi
  printf '\r\033[K  %s%s%s  %s%d/%d%s  %s%s%s\n' \
    "$color" "$glyph" "$C_RESET" \
    "$C_DIM" "$cur" "$total" "$C_RESET" \
    "$C_FG" "$desc" "$C_RESET"
}
```

输出：

```
  正在清理 3 项…

  ✓  1/3  gopls / goimports 缓存
  ✓  2/3  壁纸缓存
  ⠹  3/3  go1.16
```

> 序号格式 `1/3`，不加方括号；行内 spinner 原地变 `✓`/`✗`。

---

## 5. 完成阶段 · `render_done`

```bash
render_done() {
  if (( FREED_KB > 0 )); then
    local freed_h; freed_h=$(human_kb "$FREED_KB")
    printf '  '
    _paint "${G_OK} " "$C_BOLD$C_GREEN"
    _paint "清理完成，本次释放约 " "$C_FG"
    _paint "$freed_h" "$C_BOLD$C_GREEN"
    _paint "。" "$C_FG"
    printf '\n'
  else
    printf '  '
    _paint "清理完成。本次未观测到空间增加，文件可能仍在废纸篓或被占用。" "$C_DIM"
    printf '\n'
  fi
  nl 1
  print_disk_status
  if (( FAIL > 0 )); then
    nl 1
    printf '  '
    _paint "${G_WARN}  " "$C_YELLOW"
    _paint "${FAIL} 项执行返回非 0（可能文件被占用）" "$C_DIM"
    printf '\n'
  fi
  nl 2
  printf '  '; _paint "提示：移到废纸篓的文件需在 Finder 清空废纸篓后" "$C_DIM"; printf '\n'
  printf '  '; _paint "       才会真正腾出空间。" "$C_DIM"; printf '\n'
}
```

输出：

```
  ✓ 清理完成，本次释放约 55.2G。

  磁盘已用 62%（271Gi/460Gi），剩余 165Gi


  提示：移到废纸篓的文件需在 Finder 清空废纸篓后
         才会真正腾出空间。
```

---

## 6. 取消路径 · `render_cancel`

```bash
render_cancel() {
  nl 1
  printf '  %s已取消，未执行任何清理。%s\n' "$C_DIM" "$C_RESET"
  nl 1
}
```

---

## 7. 键盘交互速查

### 7.1 主菜单 `select` 状态

| 按键 | `FOCUS=list` | `FOCUS=button` |
|---|---|---|
| `←` | 切到上个 tab，FOCUS 重置为 list | 同左 |
| `→` | 切到下个 tab，FOCUS 重置为 list | 同左 |
| `↑` | 列表内上移（含翻页） | 焦点回到列表最末项 |
| `↓` | 列表内下移；末项再 `↓` → `FOCUS=button` | 不动 |
| `Space` | 勾选 / 取消当前项 | 无效 |
| `Enter` | 同 `Space`（勾选当前项） | 进入 confirm（若已选 > 0） |
| `a` / `A` | 全选 / 反选**当前 tab** 内所有项 | 同左 |
| `s` / `S` | 全局 safe 预设（排除重型 / 旧文件 / App / GVM / 慎清类） | 同左 |
| `c` / `C` | 全局清空所有勾选 | 同左 |
| `q` / `Q` / `Esc` | 退出 | 同左 |

### 7.2 `confirm` 状态

| 按键 | 行为 |
|---|---|
| `←` / `→` | 在 `[ 返回修改 ]` ↔ `[ 开始清理 ]` 之间切换 |
| `Enter` | 按所选按钮执行 |
| `q` / `Q` / `Esc` | 返回主菜单（不退出脚本） |

文案见 §2.6 / §3.5。

---

## 8. 验收清单

| # | 场景 | 期望 |
|---|---|---|
| 1 | 启动 → 扫描完成 | 第一屏没有 `===` 双线 header；disk strip 是「磁盘已用 75%（…/…），剩余 …」整句 |
| 2 | 扫描中 | 进度条 `━` 宽度恒 49；spinner ≥ 2s 才出现；spinner 行右端是「已用 NNs」 |
| 3 | 主菜单进入 | 第一行就是 disk strip；tabs 用「（N）」+ 3 空格分隔 |
| 4 | 当前 tab 下划线 | 长度 = tab 文本显示宽度（含括号）|
| 5 | 列表 ≤ 7 项 | 上下两行 indicator 都是空行；高度等于 > 7 项的情形 |
| 6 | 列表 > 7 项 · 首页 | 下方 `…还有 N 项 ↓`；上方空行 |
| 7 | 列表 > 7 项 · 中段 | 上下都有 `…还有 N 项 ↑/↓` |
| 8 | 列表 > 7 项 · 末页 | 上方 `…还有 N 项 ↑`；下方空行 |
| 9 | 计数行 | 仅 `共 N 项`（无任何横线）|
| 10 | 按钮未选 | `[ 开始清理 ]   未选项` 全 DIM |
| 11 | 按钮已选 + 焦点列表 | 「[ 开始清理 ]」绿 BOLD；「已选 N 项」FG；「，」DIM；「X.XG」黄 |
| 12 | 按钮已选 + 焦点按钮 | 整体绿 BOLD，含 cursor `▸` |
| 13 | 进入 confirm | 开篇是「以下 N 项 将被清理：」；分类前缀 `·` CYAN BOLD |
| 14 | confirm release | 居中的 `预计释放 55.5 GiB`，上下各 3 行空，无任何横线 |
| 15 | confirm 按钮 | `[ 返回修改 ]` 和 `[ 开始清理 ]` 都用方括号；当前按钮加 `▸` 前缀 |
| 16 | 执行 N 项 | 开篇「正在清理 N 项…」；行内 spinner 原地变 `✓`/`✗`；序号是 `N/M` 不带方括号 |
| 17 | 完成 | 第一行「✓ 清理完成，本次释放约 X G。」；下一行 disk strip |
| 18 | 空状态启动 | 单行「✓ 磁盘已经很干净了，没有需要清理的项目。」+ disk strip |
| 19 | `q/Esc` 退出 | 「已取消，未执行任何清理。」单行 DIM |
| 20 | Ctrl-C | 静默 130 退出，不渲染 cancel 行 |
| 21 | `_vwidth "（3）"` | 返回 5（两个全角括号各 2 列 + ASCII 数字 1 列）|
| 22 | `_vwidth "磁盘已用 75%"` | 返回 12 |
| 23 | `TERM=dumb` / 管道 | 全无颜色；纯文本仍可读 |
| 24 | 终端 < 64 列 | tabs / disk strip 自然 wrap；其余功能不受影响 |

---

## 9. 不变 / 不动

- 状态机：`scan → select → confirm → execute → done`
- 键位映射、信号 trap、alt screen 进出、`tput smcup` fallback
- `human_kb` 输出格式、df 解析、`du`/`find` 调用、subshell 隔离 + `set +u`
- 默认 `CONFIRM_BTN=1`、`LAYOUT_LIST_MAX=7`、慢项 spinner 阈值 `≥ 2s`

---

## 10. 实施提示

- 文案直接用文档里的中文，不要二次翻译或改写
- §0.4 的 `_vwidth` / `_lpad_to` / `_paint` 是所有中文列对齐 / 居中的基础
- 列表上下省略指示见 §2.3，必须前后各打一行（即使是空行）以保证 UI 高度稳定
- confirm 页 release banner 居中，不画任何横线（§3.3）
- 改完用 §8 的 24 项自测
- 视觉对照：`Whisper - Refined.html` 中「完整状态图 · v4 (中文母语版)」那一栏
