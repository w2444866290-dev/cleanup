/* Option A — Whisper, v3 视觉存档（共享 A_COLORS 调色板，被 v4 / tokens 引用）。*/

const A = {
  bg:    "#0e0e11",
  panel: "#15151a",
  fg:    "#e8e6e1",
  dim:   "#5a5a62",
  faint: "#7a7a83",
  green: "#a3c986",
  yellow:"#d8a657",
  red:   "#ea6962",
  blue:  "#7daea3",
  cyan:  "#89b482",
};

const ATermFrame = ({ title, children, height = 540, width = 740 }) => (
  <TermFrame width={width} height={height} title={title} bg={A.bg} chrome="#16161a" chromeFg="#6e6e76">
    {children}
  </TermFrame>
);

const Kicker = ({ subtitle }) => (
  <>
    <S c={A.faint}>  磁盘清理</S>
    {subtitle && <><S c={A.dim}>{"  ·  "}</S><S c={A.dim}>{subtitle}</S></>}
    {"\n"}
  </>
);

const Disk = ({ free = "110Gi", used = "326Gi", total = "460Gi", pct = "75%", freeColor = A.green }) => (
  <>
    <S c={A.dim}>  总容量 </S>
    <S c={A.fg}>{total}</S>
    <S c={A.dim}>{"  ·  已用 "}</S>
    <S c={A.fg}>{used}</S>
    <S c={A.dim}>{"  ·  可用 "}</S>
    <S c={freeColor} b>{free}</S>
    <S c={A.dim}>{"  ·  占用 " + pct}</S>{"\n"}
  </>
);

/* ── 1 · 扫描启动 ─────────────────────────────────────────────── */
const A_ScanIntro = () => (
  <ATermFrame title="cleanup-disk ── 扫描中">
    {"\n"}<Kicker subtitle="扫描中" />{"\n"}
    <Disk />{"\n\n"}
    <S c={A.dim}>  正在扫描可清理项，</S>
    <S c={A.fg}>~/go/pkg</S>
    <S c={A.dim}> 较大可能需 ~40 秒</S>{"\n\n\n\n\n\n\n"}
    <S c={A.dim}>  ⌃C  取消</S>{"\n"}
  </ATermFrame>
);

/* ── 2 · 扫描中 ──────────────────────────────────────────────── */
const A_Scan = () => {
  const filled = "━".repeat(30);
  const empty  = "━".repeat(19);
  return (
    <ATermFrame title="cleanup-disk ── 扫描中">
      {"\n"}<Kicker subtitle="扫描中" />{"\n"}
      <Disk />{"\n\n"}
      <S c={A.dim}>  扫描中</S>
      {"               "}<S c={A.faint}>18 / 29</S>
      {"                                "}<S c={A.fg}>62%</S>{"\n"}
      {"  "}<S c={A.green}>{filled}</S><S c={A.dim}>{empty}</S>{"\n\n\n"}
      <S c={A.cyan}>  ⣷  </S>
      <S c={A.dim}>~/go/pkg</S>
      {"                                              "}
      <S c={A.yellow}>15s</S>{"\n\n\n\n"}
      <S c={A.dim}>  ⌃C  取消</S>{"\n"}
    </ATermFrame>
  );
};

/* ── 3 · 主菜单（项数 ≤ 7，上下指示为占位空行）──────────────── */
const A_Menu = () => (
  <ATermFrame title="cleanup-disk ── 选择" height={600}>
    {"\n"}<Kicker subtitle="选择要清理的项" />{"\n"}
    <Disk />{"\n\n"}
    {"  "}
    <S c={A.green} b>开发工具缓存</S><S c={A.green}>·3</S>
    <S c={A.dim}>{"     应用缓存·3     应用数据·2     重型可选·1     GVM·6     …"}</S>{"\n"}
    {"  "}<S c={A.green}>──────────────</S>{"\n\n"}

    {/* overflow top — empty placeholder */}
    {"\n"}

    <S c={A.green} b>  ▸  </S><S c={A.dim}> ◯  </S><S c={A.yellow}>  2.6G</S>{"     "}<S c={A.fg}>gopls / goimports 缓存</S>{"\n"}
    {"      "}<S c={A.dim}>◯  </S><S c={A.yellow}>  2.4G</S>{"     "}<S c={A.fg}>npm 缓存</S> <S c={A.dim}>(~/.npm)</S>{"\n"}
    {"      "}<S c={A.green}>●  </S><S c={A.yellow}>  2.8G</S>{"     "}<S c={A.fg}>Yarn 缓存</S>{"\n"}

    {/* overflow bottom — empty placeholder */}
    {"\n\n"}

    <S c={A.dim}>  ──────────────────────────────────────────  共 3 项</S>{"\n\n"}

    {"     "}<S c={A.green} b>开始清理</S><S c={A.green}>  ›  </S>
    <S c={A.fg}>已选 1 项</S>
    <S c={A.dim}> · </S>
    <S c={A.yellow}>2.8G</S>{"\n\n\n"}

    <S c={A.dim}>  ← → 切 tab    ↑↓ 移动    空格 勾选    a 全选    s safe    c 清空    q 退出</S>{"\n"}
  </ATermFrame>
);

/* ── 3.b · 主菜单（项数 > 7，上下都有省略指示）─────────────── */
const A_MenuOverflow = () => (
  <ATermFrame title="cleanup-disk ── 选择 · 省略示意" height={600}>
    {"\n"}<Kicker subtitle="选择要清理的项" />{"\n"}
    <Disk />{"\n\n"}
    {"  "}
    <S c={A.dim}>开发工具缓存·3     </S>
    <S c={A.green} b>不常用 App·11</S>
    <S c={A.dim}>{"     超大 App·15     …"}</S>{"\n"}
    {"                     "}<S c={A.green}>─────────────</S>{"\n\n"}

    {/* overflow top */}
    <S c={A.dim}>  …其余 2 项 ↑</S>{"\n"}

    {"      "}<S c={A.dim}>◯  </S><S c={A.yellow}>  1.2G</S>{"     "}<S c={A.fg}>Sketch.app</S> <S c={A.dim}>(180 天+ 未启动)</S>{"\n"}
    <S c={A.green} b>  ▸  </S><S c={A.dim}> ◯  </S><S c={A.yellow}>  0.9G</S>{"     "}<S c={A.fg}>Affinity Designer.app</S>{"\n"}
    {"      "}<S c={A.green}>●  </S><S c={A.yellow}>  5.3G</S>{"     "}<S c={A.fg}>Pixelmator Pro.app</S>{"\n"}
    {"      "}<S c={A.dim}>◯  </S><S c={A.yellow}>  0.4G</S>{"     "}<S c={A.fg}>Skim.app</S>{"\n"}
    {"      "}<S c={A.dim}>◯  </S><S c={A.yellow}>  7.7G</S>{"     "}<S c={A.fg}>Logic Pro.app</S>{"\n"}
    {"      "}<S c={A.dim}>◯  </S><S c={A.yellow}> 11.0G</S>{"     "}<S c={A.fg}>Xcode-13.2.1.app</S>{"\n"}
    {"      "}<S c={A.dim}>◯  </S><S c={A.yellow}>  2.1G</S>{"     "}<S c={A.fg}>Things 3.app</S>{"\n"}

    {/* overflow bottom */}
    <S c={A.dim}>  …其余 2 项 ↓</S>{"\n\n"}

    <S c={A.dim}>  ──────────────────────────────────────────  共 11 项</S>{"\n\n"}

    {"     "}<S c={A.green} b>开始清理</S><S c={A.green}>  ›  </S>
    <S c={A.fg}>已选 1 项</S>
    <S c={A.dim}> · </S>
    <S c={A.yellow}>5.3G</S>{"\n\n\n"}

    <S c={A.dim}>  ← → 切 tab    ↑↓ 移动    空格 勾选    a 全选    s safe    c 清空    q 退出</S>{"\n"}
  </ATermFrame>
);

/* ── 4 · 按钮四态 ────────────────────────────────────────────── */
const A_Buttons = () => (
  <ATermFrame title="按钮状态" height={540}>
    {"\n"}
    <S c={A.faint}>  开始清理按钮</S><S c={A.dim}>{"  ·  4 种状态"}</S>{"\n\n\n"}

    <S c={A.dim}>  ── 未选项 · 焦点 = 列表 ──────────────────────────────────</S>{"\n\n"}
    {"     "}<S c={A.dim}>开始清理  ›  未选项</S>{"\n\n\n"}

    <S c={A.dim}>  ── 未选项 · 焦点 = 按钮 ──────────────────────────────────</S>{"\n\n"}
    <S c={A.green} b>  ▸  </S><S c={A.dim}>开始清理  ›  未选项</S>{"\n\n\n"}

    <S c={A.dim}>  ── 已选 N 项 · 焦点 = 列表 ───────────────────────────────</S>{"\n\n"}
    {"     "}<S c={A.green}>开始清理</S><S c={A.green}>  ›  </S><S c={A.fg}>已选 5 项</S><S c={A.dim}> · </S><S c={A.yellow}>30.5G</S>{"\n\n\n"}

    <S c={A.dim}>  ── 已选 N 项 · 焦点 = 按钮 ───────────────────────────────</S>{"\n\n"}
    <S c={A.green} b>  ▸  </S><S c={A.green} b>开始清理</S><S c={A.green} b>  ›  </S><S c={A.green} b>已选 5 项 · 30.5G</S>{"\n"}
  </ATermFrame>
);

/* ── 5 · 空状态 ──────────────────────────────────────────────── */
const A_Empty = () => (
  <ATermFrame title="cleanup-disk ── 空" height={300}>
    {"\n\n"}
    <Kicker />{"\n"}
    <Disk free="216Gi" used="244Gi" total="460Gi" pct="53%" />{"\n\n"}
    <S c={A.green} b>  ✓  </S>
    <S c={A.fg}>没有发现可清理项，磁盘已经很干净了。</S>{"\n"}
  </ATermFrame>
);

/* ── 6 · 二次确认 ────────────────────────────────────────────── */
const A_Confirm = () => (
  <ATermFrame title="cleanup-disk ── 确认" height={620}>
    {"\n"}<Kicker subtitle="二次确认 · 共 3 项" />{"\n\n"}

    <S c={A.cyan} b>  ·  开发工具缓存</S>{"\n"}
    {"       "}<S c={A.yellow}>  2.6G</S>{"     "}<S c={A.fg}>gopls / goimports 缓存</S>{"\n\n"}

    <S c={A.cyan} b>  ·  应用数据</S> <S c={A.dim}>(慎清)</S>{"\n"}
    {"       "}<S c={A.yellow}>  6.7G</S>{"     "}<S c={A.fg}>壁纸缓存</S> <S c={A.dim}>(macOS 自动重建)</S>{"\n\n"}

    <S c={A.cyan} b>  ·  GVM</S> <S c={A.dim}>(旧 Go 版本)</S>{"\n"}
    {"       "}<S c={A.yellow}> 46.2G</S>{"     "}<S c={A.fg}>go1.16</S>  <S c={A.dim}>gos+pkgsets · gvm uninstall</S>{"\n\n\n"}

    <S c={A.dim}>  ──────────────────────────────────────────────────────────</S>{"\n"}
    <S c={A.dim}>  预计释放约</S>
    {"       "}
    <S c={A.green} b>55.5 GiB</S>{"\n"}
    <S c={A.dim}>  ──────────────────────────────────────────────────────────</S>{"\n\n\n"}

    {"       "}<S c={A.dim}>返回修改</S>
    {"               "}
    <S c={A.green} b>▸  开始清理</S>{"\n\n\n"}

    <S c={A.dim}>  ← → 切换    Enter 确认    q 返回</S>{"\n"}
  </ATermFrame>
);

/* ── 7 · 清理中 ──────────────────────────────────────────────── */
const A_Execute = () => (
  <ATermFrame title="cleanup-disk ── 清理中" height={420}>
    {"\n"}<Kicker subtitle="清理中" />{"\n\n\n"}
    <S c={A.green}>  ✓  </S><S c={A.dim}>[1/3]  </S><S c={A.fg}>gopls / goimports 缓存</S>{"\n"}
    <S c={A.green}>  ✓  </S><S c={A.dim}>[2/3]  </S><S c={A.fg}>壁纸缓存</S>{"\n"}
    <S c={A.cyan}>  ⠹  </S><S c={A.dim}>[3/3]  </S><S c={A.fg}>go1.16</S>{"\n"}
  </ATermFrame>
);

/* ── 8 · 完成 ────────────────────────────────────────────────── */
const A_Done = () => (
  <ATermFrame title="cleanup-disk ── 完成" height={460}>
    {"\n"}<Kicker subtitle="完成" />{"\n"}
    <Disk free="165Gi" used="271Gi" total="460Gi" pct="62%" />{"\n\n"}
    <S c={A.green} b>  ✓  </S><S c={A.fg}>本次释放约</S> <S c={A.green} b>55.2G</S>{"\n\n\n"}
    <S c={A.dim}>  提示：移到废纸篓的文件需在 Finder 清空废纸篓后</S>{"\n"}
    <S c={A.dim}>        才会真正腾出空间。</S>{"\n"}
  </ATermFrame>
);

/* ── 9 · 已取消 ──────────────────────────────────────────────── */
const A_Cancel = () => (
  <ATermFrame title="cleanup-disk" height={200}>
    {"\n\n"}
    <S c={A.dim}>  已取消，未执行任何清理。</S>{"\n"}
  </ATermFrame>
);

Object.assign(window, {
  A_ScanIntro, A_Scan, A_Menu, A_MenuOverflow, A_Buttons, A_Empty,
  A_Confirm, A_Execute, A_Done, A_Cancel, A_COLORS: A,
});
