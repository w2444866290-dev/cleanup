# lib/tui.sh — Whisper UI TUI 状态机 + 主循环 (zh-CN)
# 依赖：lib/ui.sh + 已填充的 CATS/SIZES/SIZES_KB/DESCS/CMDS
# 产出：QUIT / EXECUTE / SEL_FLAGS[] / SELECTED[]（1-based 编号，供 exec 用）

TOTAL=${#DESCS[@]}
if (( TOTAL == 0 )); then
  # § 2.7 空状态 — 不进 alt screen，一句话 + disk strip
  render_empty() {
    nl 1
    printf '  '
    _paint "${G_OK} "                                "$C_BOLD$C_GREEN"
    _paint "磁盘已经很干净了，没有需要清理的项目。"   "$C_FG"
    printf '\n'
    nl 1
    print_disk_status
  }
  render_empty
  exit 0
fi

declare -a SEL_FLAGS=()
for ((i=0; i<TOTAL; i++)); do SEL_FLAGS[$i]=0; done

# Tab 数据
declare -a TAB_NAMES=()
declare -a TAB_OFFSETS=()
declare -a TAB_COUNTS=()
declare -a TAB_FLAT=()
declare -a TAB_CURSORS=()
TAB_CUR=0
FOCUS=list  # list | button

build_tabs() {
  local i c last_cat="" last_tab=-1
  for i in "${!CATS[@]}"; do
    c="${CATS[$i]}"
    if [[ "$c" != "$last_cat" ]]; then
      TAB_NAMES+=("$c"); TAB_OFFSETS+=("${#TAB_FLAT[@]}"); TAB_COUNTS+=(0); TAB_CURSORS+=(0)
      last_cat="$c"; last_tab=$(( ${#TAB_NAMES[@]} - 1 ))
    fi
    TAB_FLAT+=("$i")
    TAB_COUNTS[$last_tab]=$(( TAB_COUNTS[$last_tab] + 1 ))
  done
}
build_tabs

# safe 预设排除：重型 / 旧大文件 / 不常用 App / 应用数据 / GVM / 超大 App
is_safe_cat() {
  case "$1" in
    "重型可选"*|"旧大文件"*|"不常用 App"*|"应用数据"*|"GVM 旧 Go 版本"*|"超大 App"*) return 1 ;;
    *) return 0 ;;
  esac
}

count_selected() {
  local n=0 i; for ((i=0; i<TOTAL; i++)); do
    [[ "${SEL_FLAGS[$i]}" == "1" ]] && n=$((n+1))
  done; echo "$n"
}

selected_kb_total() {
  local total=0 i; for ((i=0; i<TOTAL; i++)); do
    [[ "${SEL_FLAGS[$i]}" == "1" ]] && total=$(( total + SIZES_KB[$i] ))
  done; echo "$total"
}

current_item_idx() {
  local off=${TAB_OFFSETS[$TAB_CUR]} cur=${TAB_CURSORS[$TAB_CUR]}
  echo "${TAB_FLAT[$(( off + cur ))]}"
}

prev_tab() { (( TAB_CUR > 0 )) && TAB_CUR=$(( TAB_CUR - 1 )); }
next_tab() { (( TAB_CUR < ${#TAB_NAMES[@]} - 1 )) && TAB_CUR=$(( TAB_CUR + 1 )); }

move_in_tab() {
  local dir=$1 cnt=${TAB_COUNTS[$TAB_CUR]} cur=${TAB_CURSORS[$TAB_CUR]}
  cur=$(( cur + dir ))
  (( cur < 0 )) && cur=0
  (( cur >= cnt )) && cur=$(( cnt - 1 ))
  TAB_CURSORS[$TAB_CUR]=$cur
}

toggle_current_in_tab() {
  local idx; idx=$(current_item_idx)
  if [[ "${SEL_FLAGS[$idx]}" == "1" ]]; then SEL_FLAGS[$idx]=0
  else SEL_FLAGS[$idx]=1
  fi
}

toggle_all_in_tab() {
  local off=${TAB_OFFSETS[$TAB_CUR]} cnt=${TAB_COUNTS[$TAB_CUR]}
  local all_sel=1 j idx
  for ((j=0; j<cnt; j++)); do
    idx=${TAB_FLAT[$(( off + j ))]}
    [[ "${SEL_FLAGS[$idx]}" != "1" ]] && { all_sel=0; break; }
  done
  for ((j=0; j<cnt; j++)); do
    idx=${TAB_FLAT[$(( off + j ))]}
    if (( all_sel == 1 )); then SEL_FLAGS[$idx]=0
    else                        SEL_FLAGS[$idx]=1
    fi
  done
}

select_safe() {
  local i; for ((i=0; i<TOTAL; i++)); do
    if is_safe_cat "${CATS[$i]}"; then SEL_FLAGS[$i]=1
    else                                SEL_FLAGS[$i]=0
    fi
  done
}

clear_all() {
  local i; for ((i=0; i<TOTAL; i++)); do SEL_FLAGS[$i]=0; done
}

# ── Render: tabs line · § 2.1 ────────────────────────────────
# 全角括号 （N）  +  3 空格分隔，无 · 接合符
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

# ── Render: list (§ 2.2) + overflow indicators (§ 2.3) ──
declare -a LIST_VIEW=()
LIST_OFFSET=0
LIST_TOTAL=0
CURSOR_ROW=0

build_list_view() {
  LIST_VIEW=()
  local cnt=${TAB_COUNTS[$TAB_CUR]}
  local cur=${TAB_CURSORS[$TAB_CUR]}
  local off=${TAB_OFFSETS[$TAB_CUR]}
  LIST_TOTAL=$cnt
  local page=$(( cur / LAYOUT_LIST_MAX ))
  LIST_OFFSET=$(( page * LAYOUT_LIST_MAX ))
  local p_end=$(( LIST_OFFSET + LAYOUT_LIST_MAX ))
  (( p_end > cnt )) && p_end=$cnt
  CURSOR_ROW=$(( cur - LIST_OFFSET ))
  local j idx checked
  for ((j=LIST_OFFSET; j<p_end; j++)); do
    idx=${TAB_FLAT[$(( off + j ))]}
    checked="${SEL_FLAGS[$idx]}"
    LIST_VIEW+=("${checked}|${SIZES[$idx]}|${DESCS[$idx]}")
  done
}

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

# ── Render: count line · § 2.4 ───────────────────────────────
# 无横线，仅 「共 N 项」
render_count_line() {
  printf '  %s共 %d 项%s\n' "$C_DIM" "$LIST_TOTAL" "$C_RESET"
}

# ── Render: clean now button · § 2.5 ─────────────────────────
# [ 开始清理 ] 中文方括号风，分隔用中文逗号 ，
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

# ── Render: keys hint · § 2.6 ────────────────────────────────
render_keys_select() {
  printf '  %s← → 切 tab    ↑↓ 移动    空格 勾选    a 全选    s safe    c 清空    q 退出%s\n' \
    "$C_DIM" "$C_RESET"
}

# ── Render: select screen · § 2.0 ────────────────────────────
# 第一行就是 disk strip，无 kicker
render_select() {
  clear
  print_disk_status
  nl 1
  render_tabs_line
  nl 1
  build_list_view
  render_list_overflow_top
  render_list
  render_list_overflow_bottom
  nl 1
  render_count_line
  nl 1
  local sn st
  sn=$(count_selected)
  if (( sn > 0 )); then st=$(human_kb "$(selected_kb_total)"); else st=""; fi
  render_clean_button "$sn" "$st"
  nl 2
  render_keys_select
}

# ── Render: confirm screen · § 3 ─────────────────────────────
CONFIRM_BTN=1  # 0=返回修改, 1=开始清理 (默认 1)
declare -a CONFIRM_ITEMS=()
RELEASE_TOTAL=""

build_confirm_items() {
  CONFIRM_ITEMS=()
  local total=0 i cat note
  for ((i=0; i<TOTAL; i++)); do
    [[ "${SEL_FLAGS[$i]}" != "1" ]] && continue
    cat="${CATS[$i]}"
    note=""
    if [[ "$cat" =~ ^(.+)\ +\((.+)\)[[:space:]]*$ ]]; then
      cat="${BASH_REMATCH[1]}"
      note="${BASH_REMATCH[2]}"
    fi
    CONFIRM_ITEMS+=("${cat}|${note}|${SIZES[$i]}|${DESCS[$i]}|")
    total=$(( total + SIZES_KB[$i] ))
  done
  RELEASE_TOTAL=$(human_kb "$total")
}

# § 3.1 开篇 — 「以下 N 项 将被清理：」
render_confirm_opener() {
  local n=${#CONFIRM_ITEMS[@]}
  printf '  '
  _paint "以下 "        "$C_FG"
  _paint "${n} 项"      "$C_BOLD$C_GREEN"
  _paint " 将被清理："   "$C_FG"
  printf '\n'
}

# § 3.2 分类组 — 备注用全角括号（）
render_confirm_groups() {
  local prev_cat="" cat note size desc desc_note row
  for row in "${CONFIRM_ITEMS[@]}"; do
    IFS='|' read -r cat note size desc desc_note <<<"$row"
    if [[ "$cat" != "$prev_cat" ]]; then
      [[ -n "$prev_cat" ]] && nl 1
      if [[ -n "$note" ]]; then
        printf '  %s%s  %s%s%s（%s）%s\n' \
          "$C_BOLD$C_CYAN" "$G_CAT_BULLET" "$cat" "$C_RESET" \
          "$C_DIM" "$note" "$C_RESET"
      else
        printf '  %s%s  %s%s\n' \
          "$C_BOLD$C_CYAN" "$G_CAT_BULLET" "$cat" "$C_RESET"
      fi
      prev_cat="$cat"
    fi
    if [[ -n "$desc_note" ]]; then
      printf '       %s%6s%s     %s%s（%s）%s\n' \
        "$C_YELLOW" "$size" "$C_RESET" "$desc" "$C_DIM" "$desc_note" "$C_RESET"
    else
      printf '       %s%6s%s     %s\n' \
        "$C_YELLOW" "$size" "$C_RESET" "$desc"
    fi
  done
}

# § 3.3 释放总量 — 居中 + 加粗，无横线
render_release_banner() {
  local total=$1
  local plain="预计释放 ${total}"
  local w; w=$(_vwidth "$plain")
  local pad=$(( (LAYOUT_WIDTH - w) / 2 )); (( pad < 0 )) && pad=0

  printf '%*s' "$pad" ""
  _paint "预计释放 "   "$C_FG"
  _paint "$total"      "$C_BOLD$C_GREEN"
  printf '\n'
}

# § 3.4 按钮 — [ 返回修改 ] / [ 开始清理 ]，光标 ▸ 前缀
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

render_keys_confirm() {
  printf '  %s← → 切换    Enter 确认    q 返回%s\n' "$C_DIM" "$C_RESET"
}

# § 3.0 整体流水
render_confirm() {
  clear
  build_confirm_items
  render_confirm_opener
  nl 2
  render_confirm_groups
  nl 3
  render_release_banner "$RELEASE_TOTAL"
  nl 3
  render_confirm_buttons
  nl 2
  render_keys_confirm
}

# ── 单字符按键读取（含方向键 ESC 序列） ────────────────────
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

# ── alt screen + 隐藏光标 + 关闭回显 ───────────────────────
SAVE_STTY=$(stty -g 2>/dev/null)
restore_tui() {
  [[ -n "${SAVE_STTY:-}" ]] && stty "$SAVE_STTY" 2>/dev/null
  tput cnorm 2>/dev/null || printf '\033[?25h'
  printf '\033[H\033[2J\033[3J'
  tput rmcup 2>/dev/null || printf '\033[?1049l'
}
trap 'restore_tui; exit 130' INT TERM
tput smcup 2>/dev/null || printf '\033[?1049h'
tput civis 2>/dev/null || printf '\033[?25l'
stty -echo 2>/dev/null

# ── 主循环 ───────────────────────────────────────────────────
STATE="select"
QUIT=0
EXECUTE=0
while :; do
  if [[ "$STATE" == "select" ]]; then
    render_select
  else
    render_confirm
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
            _cnt=${TAB_COUNTS[$TAB_CUR]}
            (( _cnt > 0 )) && TAB_CURSORS[$TAB_CUR]=$(( _cnt - 1 ))
          else
            move_in_tab -1
          fi
          ;;
        DOWN)
          if [[ "$FOCUS" == "list" ]]; then
            _cnt=${TAB_COUNTS[$TAB_CUR]}
            _cur=${TAB_CURSORS[$TAB_CUR]}
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

# Cancel path · § 6
render_cancel() {
  nl 1
  printf '  %s已取消，未执行任何清理。%s\n' "$C_DIM" "$C_RESET"
  nl 1
}

if (( QUIT == 1 )) || (( EXECUTE == 0 )); then
  render_cancel
  exit 0
fi

declare -a SELECTED=()
for ((i=0; i<TOTAL; i++)); do
  [[ "${SEL_FLAGS[$i]}" == "1" ]] && SELECTED+=("$(( i + 1 ))")
done
