# lib/tui.sh — TUI 状态机 + 主循环
# 依赖：lib/ui.sh + 已填充的 CATS/SIZES/SIZES_KB/DESCS/CMDS
# 产出：QUIT / EXECUTE / SEL_FLAGS[] / SELECTED[]（1-based 编号，供 exec 用）
#
# 屏幕分两态：
#   STATE=select  : 顶部 tabs + 分页列表 + 开始清理按钮（FOCUS=list|button）
#   STATE=confirm : 选中项 + 总大小 + [返回修改] / [开始清理] 两个按钮

TOTAL=${#DESCS[@]}
if (( TOTAL == 0 )); then
  ok "没有发现可清理项，磁盘已经很干净了 🎉"
  exit 0
fi

# 与 DESCS 平行的选中标记
declare -a SEL_FLAGS=()
for ((i=0; i<TOTAL; i++)); do SEL_FLAGS[$i]=0; done

# Tab 数据结构（按 CATS 拍平为一维，bash 3.2 兼容）
declare -a UNIQ_CATS=()    # 分类名（按出现顺序去重）
declare -a TAB_OFFSETS=()  # 每个 tab 在 TAB_FLAT 中的起始偏移
declare -a TAB_COUNTS=()   # 每个 tab 的项目数
declare -a TAB_FLAT=()     # 拍平：tab 内顺序的 DESCS 全局索引
declare -a TAB_CURSORS=()  # 每个 tab 内的光标位置（0-based）
CUR_TAB=0
PAGE_SIZE=7
FOCUS=list  # list | button —— ↓ 到列表末再按 ↓ 进入按钮，按钮 ↑ 回到列表末

build_tabs() {
  local i c last_cat="" last_tab=-1
  for i in "${!CATS[@]}"; do
    c="${CATS[$i]}"
    if [[ "$c" != "$last_cat" ]]; then
      UNIQ_CATS+=("$c")
      TAB_OFFSETS+=("${#TAB_FLAT[@]}")
      TAB_COUNTS+=(0)
      TAB_CURSORS+=(0)
      last_cat="$c"
      last_tab=$(( ${#UNIQ_CATS[@]} - 1 ))
    fi
    TAB_FLAT+=("$i")
    TAB_COUNTS[$last_tab]=$(( TAB_COUNTS[$last_tab] + 1 ))
  done
}
build_tabs

# ---- 选择 helper ----
# safe 预设排除：重型可选 / 旧大文件 / 不常用 App / 应用数据 / GVM 旧 Go 版本 / 超大 App
is_safe_cat() {
  case "$1" in
    "重型可选"*|"旧大文件"*|"不常用 App"*|"应用数据"*|"GVM 旧 Go 版本"*|"超大 App"*) return 1 ;;
    *) return 0 ;;
  esac
}

count_selected() {
  local n=0 i
  for ((i=0; i<TOTAL; i++)); do
    [[ "${SEL_FLAGS[$i]}" == "1" ]] && n=$((n+1))
  done
  echo "$n"
}

selected_kb_total() {
  local total=0 i
  for ((i=0; i<TOTAL; i++)); do
    [[ "${SEL_FLAGS[$i]}" == "1" ]] && total=$(( total + SIZES_KB[$i] ))
  done
  echo "$total"
}

current_item_idx() {
  local off=${TAB_OFFSETS[$CUR_TAB]}
  local cur=${TAB_CURSORS[$CUR_TAB]}
  echo "${TAB_FLAT[$(( off + cur ))]}"
}

prev_tab() { (( CUR_TAB > 0 )) && CUR_TAB=$(( CUR_TAB - 1 )); }
next_tab() { (( CUR_TAB < ${#UNIQ_CATS[@]} - 1 )) && CUR_TAB=$(( CUR_TAB + 1 )); }

move_in_tab() {
  local dir=$1 cnt=${TAB_COUNTS[$CUR_TAB]} cur=${TAB_CURSORS[$CUR_TAB]}
  cur=$(( cur + dir ))
  (( cur < 0 )) && cur=0
  (( cur >= cnt )) && cur=$(( cnt - 1 ))
  TAB_CURSORS[$CUR_TAB]=$cur
}

toggle_current_in_tab() {
  local idx
  idx=$(current_item_idx)
  if [[ "${SEL_FLAGS[$idx]}" == "1" ]]; then
    SEL_FLAGS[$idx]=0
  else
    SEL_FLAGS[$idx]=1
  fi
}

# 当前 tab 全选；若已全选则取消全选
toggle_all_in_tab() {
  local off=${TAB_OFFSETS[$CUR_TAB]} cnt=${TAB_COUNTS[$CUR_TAB]}
  local all_sel=1 j idx
  for ((j=0; j<cnt; j++)); do
    idx=${TAB_FLAT[$(( off + j ))]}
    [[ "${SEL_FLAGS[$idx]}" != "1" ]] && { all_sel=0; break; }
  done
  for ((j=0; j<cnt; j++)); do
    idx=${TAB_FLAT[$(( off + j ))]}
    if (( all_sel == 1 )); then
      SEL_FLAGS[$idx]=0
    else
      SEL_FLAGS[$idx]=1
    fi
  done
}

select_safe() {
  local i
  for ((i=0; i<TOTAL; i++)); do
    if is_safe_cat "${CATS[$i]}"; then
      SEL_FLAGS[$i]=1
    else
      SEL_FLAGS[$i]=0
    fi
  done
}

clear_all() {
  local i
  for ((i=0; i<TOTAL; i++)); do SEL_FLAGS[$i]=0; done
}

# 居中绘制 "──── <label> ────"，宽度约 64 字符
draw_footer_line() {
  local label="$1"
  local total_w=64
  # bash 3.2 ${#var} 对中文返回字节数（UTF-8 中文 3 字节，显示宽度 2）。
  # 用 (total_w - 字节宽度/1.5) 估算左右填充。
  local label_bytes=${#label}
  local pad=$(( (total_w - label_bytes * 2 / 3) / 2 ))
  (( pad < 4 )) && pad=4
  local line="" i
  for ((i=0; i<pad; i++)); do line+="─"; done
  printf '%s%s %s %s%s\n' "$C_DIM" "$line" "$label" "$line" "$C_RESET"
}

# ---- draw_select ----
draw_select() {
  printf '\033[2J\033[H'
  # 顶部：分隔线 + 标题 + tabs + 分隔线
  printf '%s================================================================%s\n' "$C_BOLD$C_BLUE" "$C_RESET"
  printf '%s磁盘清理 — 选择要清理的项%s\n' "$C_BOLD$C_BLUE" "$C_RESET"
  local t name
  for t in "${!UNIQ_CATS[@]}"; do
    name="${UNIQ_CATS[$t]}(${TAB_COUNTS[$t]})"
    if (( t == CUR_TAB )); then
      printf '%s%s[%s]%s ' "$C_BOLD" "$C_GREEN" "$name" "$C_RESET"
    else
      printf '%s[%s]%s ' "$C_DIM" "$name" "$C_RESET"
    fi
  done
  printf '\n'
  printf '%s================================================================%s\n' "$C_BOLD$C_BLUE" "$C_RESET"

  # 当前 tab 分页计算
  local cnt=${TAB_COUNTS[$CUR_TAB]}
  local cur=${TAB_CURSORS[$CUR_TAB]}
  local off=${TAB_OFFSETS[$CUR_TAB]}
  local page=$(( cur / PAGE_SIZE ))
  local p_start=$(( page * PAGE_SIZE ))
  local p_end=$(( p_start + PAGE_SIZE ))
  (( p_end > cnt )) && p_end=$cnt
  local before=$p_start
  local after=$(( cnt - p_end ))

  echo
  # 上方"其余 N 项 ↑"（空行占位保持垂直位置稳定）
  if (( before > 0 )); then
    printf '  %s... (其余 %d 项 ↑)%s\n' "$C_DIM" "$before" "$C_RESET"
  else
    echo
  fi

  # 当前页列表行（≤ PAGE_SIZE）；光标只在 FOCUS=list 时显示
  local j idx box marker
  for ((j=p_start; j<p_end; j++)); do
    idx=${TAB_FLAT[$(( off + j ))]}
    if (( j == cur )) && [[ "$FOCUS" == "list" ]]; then
      marker="${C_BOLD}${C_GREEN}▶${C_RESET} "
    else
      marker="  "
    fi
    if [[ "${SEL_FLAGS[$idx]}" == "1" ]]; then
      box="${C_GREEN}[✓]${C_RESET}"
    else
      box="[ ]"
    fi
    printf '%s%s  %s[%7s]%s  %s\n' \
      "$marker" "$box" \
      "$C_YELLOW" "${SIZES[$idx]}" "$C_RESET" \
      "${DESCS[$idx]}"
  done

  # 下方"其余 N 项 ↓"
  if (( after > 0 )); then
    printf '  %s... (其余 %d 项 ↓)%s\n' "$C_DIM" "$after" "$C_RESET"
  else
    echo
  fi

  echo
  draw_footer_line "共 ${cnt} 项"
  echo

  # 开始清理按钮（FOCUS=button 时显示 ▶ 且加粗；selected==0 时暗色不可点）
  local s_cnt s_total btn_marker
  s_cnt=$(count_selected)
  s_total=$(selected_kb_total)
  if [[ "$FOCUS" == "button" ]]; then
    btn_marker="${C_BOLD}${C_GREEN}▶${C_RESET} "
  else
    btn_marker="  "
  fi
  if (( s_cnt == 0 )); then
    printf '%s%s[ 开始清理 ➜ 未选项 ]%s\n' "$btn_marker" "$C_DIM" "$C_RESET"
  elif [[ "$FOCUS" == "button" ]]; then
    printf '%s%s%s[ 开始清理 ➜ 已选 %d 项, 预估上限 %s ]%s\n' \
      "$btn_marker" "$C_BOLD" "$C_GREEN" "$s_cnt" "$(human_kb "$s_total")" "$C_RESET"
  else
    printf '%s%s[ 开始清理 ➜ 已选 %d 项, 预估上限 %s ]%s\n' \
      "$btn_marker" "$C_GREEN" "$s_cnt" "$(human_kb "$s_total")" "$C_RESET"
  fi
  echo
  printf '%s← → 切 tab   ↑↓ 移动/翻页 (↓ 到底进入按钮)   Space/Enter 勾选   a 全选当前tab   s safe   c 清空   q 退出%s\n' \
    "$C_DIM" "$C_RESET"
  printf '\033[J'
}

# ---- draw_confirm ----
CONFIRM_BTN=1  # 0=返回修改, 1=开始清理（默认选"开始清理"）
draw_confirm() {
  printf '\033[2J\033[H'
  printf '%s================================================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
  printf '%s二次确认 — 以下将被清理 (共 %d 项)%s\n' "$C_BOLD$C_YELLOW" "$(count_selected)" "$C_RESET"
  printf '%s================================================================%s\n' "$C_BOLD$C_YELLOW" "$C_RESET"
  echo

  local i total=0 prev=""
  for ((i=0; i<TOTAL; i++)); do
    [[ "${SEL_FLAGS[$i]}" != "1" ]] && continue
    if [[ "${CATS[$i]}" != "$prev" ]]; then
      printf '\n%s● %s%s\n' "$C_BOLD$C_CYAN" "${CATS[$i]}" "$C_RESET"
      prev="${CATS[$i]}"
    fi
    printf '  %s[%7s]%s  %s\n' "$C_YELLOW" "${SIZES[$i]}" "$C_RESET" "${DESCS[$i]}"
    total=$(( total + SIZES_KB[$i] ))
  done

  echo
  printf '%s----------------------------------------------------------------%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
  printf '  预估上限: %s%s%s   %s(实际释放可能较少：APFS clone/硬链接的共享空间会被重复计算)%s\n' \
    "$C_BOLD$C_GREEN" "$(human_kb "$total")" "$C_RESET" \
    "$C_DIM" "$C_RESET"
  printf '%s----------------------------------------------------------------%s\n' "$C_BOLD$C_GREEN" "$C_RESET"
  echo

  if (( CONFIRM_BTN == 0 )); then
    printf '  %s%s▶ [ 返回修改 ]%s     %s[ 开始清理 ]%s\n' \
      "$C_BOLD" "$C_RED" "$C_RESET" "$C_DIM" "$C_RESET"
  else
    printf '  %s[ 返回修改 ]%s     %s%s▶ [ 开始清理 ]%s\n' \
      "$C_DIM" "$C_RESET" "$C_BOLD" "$C_GREEN" "$C_RESET"
  fi
  echo
  printf '%s← → 切换按钮   Enter 确认   q/Esc 返回修改%s\n' "$C_DIM" "$C_RESET"
  printf '\033[J'
}

# ---- 单字符按键读取（含方向键 ESC 序列） ----
read_key() {
  local k seq
  IFS= read -rsn1 k
  if [[ "$k" == $'\x1b' ]]; then
    IFS= read -rsn2 -t 1 seq
    case "$seq" in
      '[A') KEY=UP ;;
      '[B') KEY=DOWN ;;
      '[C') KEY=RIGHT ;;
      '[D') KEY=LEFT ;;
      '')   KEY=ESC ;;
      *)    KEY="" ;;
    esac
  elif [[ -z "$k" ]]; then
    KEY=ENTER
  elif [[ "$k" == " " ]]; then
    KEY=SPACE
  else
    KEY="$k"
  fi
}

# ---- alt screen + 隐藏光标 + 关闭回显 ----
SAVE_STTY=$(stty -g 2>/dev/null)
restore_tui() {
  [[ -n "${SAVE_STTY:-}" ]] && stty "$SAVE_STTY" 2>/dev/null
  tput cnorm 2>/dev/null || printf '\033[?25h'
  # 先清空 alt screen 内容，再退出 alt screen。
  # 某些终端 (iTerm2/Terminal.app 特定设置) 在 rmcup 时会把 alt screen 残留 echo
  # 一次到主 scrollback —— 先清空就不会有内容可 echo
  printf '\033[H\033[2J\033[3J'
  tput rmcup 2>/dev/null || printf '\033[?1049l'
}
trap 'restore_tui; exit 130' INT TERM
tput smcup 2>/dev/null || printf '\033[?1049h'
tput civis 2>/dev/null || printf '\033[?25l'
stty -echo 2>/dev/null

# ---- 主循环 ----
STATE="select"
QUIT=0
EXECUTE=0
while :; do
  if [[ "$STATE" == "select" ]]; then
    draw_select
  else
    draw_confirm
  fi
  read_key
  case "$STATE" in
    select)
      case "$KEY" in
        LEFT)    prev_tab; FOCUS=list ;;
        RIGHT)   next_tab; FOCUS=list ;;
        UP)
          if [[ "$FOCUS" == "button" ]]; then
            FOCUS=list
            _cnt=${TAB_COUNTS[$CUR_TAB]}
            (( _cnt > 0 )) && TAB_CURSORS[$CUR_TAB]=$(( _cnt - 1 ))
          else
            move_in_tab -1
          fi
          ;;
        DOWN)
          if [[ "$FOCUS" == "list" ]]; then
            _cnt=${TAB_COUNTS[$CUR_TAB]}
            _cur=${TAB_CURSORS[$CUR_TAB]}
            if (( _cur >= _cnt - 1 )); then
              FOCUS=button
            else
              move_in_tab 1
            fi
          fi
          ;;
        SPACE)
          [[ "$FOCUS" == "list" ]] && toggle_current_in_tab
          ;;
        ENTER)
          if [[ "$FOCUS" == "list" ]]; then
            toggle_current_in_tab
          elif [[ "$FOCUS" == "button" ]]; then
            if (( $(count_selected) > 0 )); then
              STATE=confirm
              CONFIRM_BTN=1
            fi
          fi
          ;;
        a|A)     toggle_all_in_tab ;;
        s|S)     select_safe ;;
        c|C)     clear_all ;;
        q|Q|ESC) QUIT=1; break ;;
      esac
      ;;
    confirm)
      case "$KEY" in
        LEFT|RIGHT) CONFIRM_BTN=$(( 1 - CONFIRM_BTN )) ;;
        ENTER)
          if (( CONFIRM_BTN == 1 )); then
            EXECUTE=1
            break
          else
            STATE=select
          fi
          ;;
        q|Q|ESC) STATE=select ;;
      esac
      ;;
  esac
done

restore_tui
trap - INT TERM

if (( QUIT == 1 )) || (( EXECUTE == 0 )); then
  note "已取消，未执行任何清理。"
  exit 0
fi

# 把 SEL_FLAGS 转成 1-based 编号数组 SELECTED（升序），供 exec 用
declare -a SELECTED=()
for ((i=0; i<TOTAL; i++)); do
  [[ "${SEL_FLAGS[$i]}" == "1" ]] && SELECTED+=("$(( i + 1 ))")
done
