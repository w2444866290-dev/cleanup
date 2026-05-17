/* Option A — Whisper (中文母语版).
   Design decisions:
   - 砍掉 kicker 行；每屏开头是动作/状态短句
   - disk strip 句子化（"磁盘已用 75%（326Gi/460Gi），剩余 110Gi"）
   - tabs 用全角空格分隔 + 计数放进括号 （3）
   - 按钮 [ 开始清理 ] 中文 CLI 惯例；分隔用中文逗号
   - confirm release banner 不画横线，靠留白和加粗居中
   - execute 行：序号 1/3 不带方括号
   - 列表 overflow 用「还有 N 项」口吻
*/

const V4 = window.A_COLORS;

const V4Frame = ({ title, children, height = 540, width = 740 }) => (
  <TermFrame width={width} height={height} title={title} bg={V4.bg} chrome="#16161a" chromeFg="#6e6e76">
    {children}
  </TermFrame>
);

const DiskV4 = ({ used="326Gi", total="460Gi", pct="75%", free="110Gi" }) => (
  <>
    <S c={V4.dim}>  磁盘已用 </S>
    <S c={V4.fg}>{pct}</S>
    <S c={V4.dim}>（</S>
    <S c={V4.fg}>{used}</S>
    <S c={V4.dim}>/</S>
    <S c={V4.fg}>{total}</S>
    <S c={V4.dim}>），剩余 </S>
    <S c={V4.green} b>{free}</S>{"\n"}
  </>
);

/* ── 1 · 扫描启动 ────────────────────────────────────────────── */
const V4_ScanIntro = () => (
  <V4Frame title="cleanup-disk">
    {"\n"}
    <S c={V4.fg}>  正在扫描可清理项</S>
    <S c={V4.dim}>，</S>
    <S c={V4.fg}>~/go/pkg</S>
    <S c={V4.dim}> 较大，预计需要 ~40 秒</S>{"\n\n"}
    <DiskV4 />{"\n\n\n\n\n\n"}
    <S c={V4.dim}>  ⌃C  取消</S>{"\n"}
  </V4Frame>
);

/* ── 2 · 扫描中 ──────────────────────────────────────────────── */
const V4_Scan = () => {
  const filled = "━".repeat(30);
  const empty  = "━".repeat(19);
  return (
    <V4Frame title="cleanup-disk">
      {"\n"}
      <S c={V4.fg}>  正在扫描 </S>
      <S c={V4.faint}>18/29</S>
      <S c={V4.fg}> 项…</S>
      {"                                          "}<S c={V4.fg}>62%</S>{"\n"}
      {"  "}<S c={V4.green}>{filled}</S><S c={V4.dim}>{empty}</S>{"\n\n\n"}
      <S c={V4.cyan}>  ⣷  </S>
      <S c={V4.dim}>~/go/pkg</S>
      {"                                          "}
      <S c={V4.dim}>已用 </S>
      <S c={V4.yellow}>15s</S>{"\n\n\n\n"}
      <S c={V4.dim}>  ⌃C  取消</S>{"\n"}
    </V4Frame>
  );
};

/* ── 3 · 主菜单（≤7 项）─────────────────────────────────────── */
const V4_Menu = () => (
  <V4Frame title="cleanup-disk" height={600}>
    {"\n"}
    <DiskV4 />{"\n"}
    {"  "}
    <S c={V4.green} b>开发工具缓存</S><S c={V4.green}>（3）</S>
    <S c={V4.dim}>{"   应用缓存（3）   应用数据（2）   重型可选（1）   GVM（6）   …"}</S>{"\n"}
    {"  "}<S c={V4.green}>────────────────</S>{"\n\n"}

    {/* overflow top — empty placeholder */}
    {"\n"}

    <S c={V4.green} b>  ▸  </S><S c={V4.dim}> ◯  </S><S c={V4.yellow}>  2.6G</S>{"     "}<S c={V4.fg}>gopls / goimports 缓存</S>{"\n"}
    {"      "}<S c={V4.dim}>◯  </S><S c={V4.yellow}>  2.4G</S>{"     "}<S c={V4.fg}>npm 缓存</S> <S c={V4.dim}>(~/.npm)</S>{"\n"}
    {"      "}<S c={V4.green}>●  </S><S c={V4.yellow}>  2.8G</S>{"     "}<S c={V4.fg}>Yarn 缓存</S>{"\n"}

    {/* overflow bottom — empty placeholder */}
    {"\n\n"}

    <S c={V4.dim}>  共 3 项</S>{"\n\n"}

    {"     "}<S c={V4.green} b>[ 开始清理 ]</S>{"   "}
    <S c={V4.fg}>已选 1 项</S>
    <S c={V4.dim}>，</S>
    <S c={V4.yellow}>2.8G</S>{"\n\n\n"}

    <S c={V4.dim}>  ← → 切 tab    ↑↓ 移动    空格 勾选    a 全选    s safe    c 清空    q 退出</S>{"\n"}
  </V4Frame>
);

/* ── 3.b · 主菜单（>7 项·上下都有省略）─────────────────────── */
const V4_MenuOverflow = () => (
  <V4Frame title="cleanup-disk · 省略示意" height={620}>
    {"\n"}
    <DiskV4 />{"\n"}
    {"  "}
    <S c={V4.dim}>开发工具缓存（3）   </S>
    <S c={V4.green} b>不常用 App</S><S c={V4.green}>（11）</S>
    <S c={V4.dim}>{"   超大 App（15）   …"}</S>{"\n"}
    {"                      "}<S c={V4.green}>───────────────</S>{"\n\n"}

    <S c={V4.dim}>  …还有 2 项 ↑</S>{"\n"}

    {"      "}<S c={V4.dim}>◯  </S><S c={V4.yellow}>  1.2G</S>{"     "}<S c={V4.fg}>Sketch.app</S> <S c={V4.dim}>(180 天+ 未启动)</S>{"\n"}
    <S c={V4.green} b>  ▸  </S><S c={V4.dim}> ◯  </S><S c={V4.yellow}>  0.9G</S>{"     "}<S c={V4.fg}>Affinity Designer.app</S>{"\n"}
    {"      "}<S c={V4.green}>●  </S><S c={V4.yellow}>  5.3G</S>{"     "}<S c={V4.fg}>Pixelmator Pro.app</S>{"\n"}
    {"      "}<S c={V4.dim}>◯  </S><S c={V4.yellow}>  0.4G</S>{"     "}<S c={V4.fg}>Skim.app</S>{"\n"}
    {"      "}<S c={V4.dim}>◯  </S><S c={V4.yellow}>  7.7G</S>{"     "}<S c={V4.fg}>Logic Pro.app</S>{"\n"}
    {"      "}<S c={V4.dim}>◯  </S><S c={V4.yellow}> 11.0G</S>{"     "}<S c={V4.fg}>Xcode-13.2.1.app</S>{"\n"}
    {"      "}<S c={V4.dim}>◯  </S><S c={V4.yellow}>  2.1G</S>{"     "}<S c={V4.fg}>Things 3.app</S>{"\n"}

    <S c={V4.dim}>  …还有 2 项 ↓</S>{"\n\n"}

    <S c={V4.dim}>  共 11 项</S>{"\n\n"}

    {"     "}<S c={V4.green} b>[ 开始清理 ]</S>{"   "}
    <S c={V4.fg}>已选 1 项</S>
    <S c={V4.dim}>，</S>
    <S c={V4.yellow}>5.3G</S>{"\n\n\n"}

    <S c={V4.dim}>  ← → 切 tab    ↑↓ 移动    空格 勾选    a 全选    s safe    c 清空    q 退出</S>{"\n"}
  </V4Frame>
);

/* ── 4 · 按钮 4 态 ───────────────────────────────────────────── */
const V4_Buttons = () => (
  <V4Frame title="按钮状态" height={540}>
    {"\n"}
    <S c={V4.faint}>  开始清理按钮 · 4 种状态</S>{"\n\n\n"}

    <S c={V4.dim}>  ── 未选项 · 焦点在列表 ──────────────────────────────────</S>{"\n\n"}
    {"     "}<S c={V4.dim}>[ 开始清理 ]   未选项</S>{"\n\n\n"}

    <S c={V4.dim}>  ── 未选项 · 焦点在按钮 ──────────────────────────────────</S>{"\n\n"}
    <S c={V4.green} b>  ▸  </S><S c={V4.dim}>[ 开始清理 ]   未选项</S>{"\n\n\n"}

    <S c={V4.dim}>  ── 已选 N 项 · 焦点在列表 ───────────────────────────────</S>{"\n\n"}
    {"     "}<S c={V4.green} b>[ 开始清理 ]</S>{"   "}<S c={V4.fg}>已选 5 项</S><S c={V4.dim}>，</S><S c={V4.yellow}>30.5G</S>{"\n\n\n"}

    <S c={V4.dim}>  ── 已选 N 项 · 焦点在按钮 ───────────────────────────────</S>{"\n\n"}
    <S c={V4.green} b>  ▸  </S><S c={V4.green} b>[ 开始清理 ]</S><S c={V4.green} b>   已选 5 项，30.5G</S>{"\n"}
  </V4Frame>
);

/* ── 5 · 空状态 ──────────────────────────────────────────────── */
const V4_Empty = () => (
  <V4Frame title="cleanup-disk" height={280}>
    {"\n\n"}
    <S c={V4.green} b>  ✓ </S>
    <S c={V4.fg}>磁盘已经很干净了，没有需要清理的项目。</S>{"\n\n"}
    <DiskV4 free="216Gi" used="244Gi" total="460Gi" pct="53%" />
  </V4Frame>
);

/* ── 6 · 二次确认 ────────────────────────────────────────────── */
const V4_Confirm = () => (
  <V4Frame title="cleanup-disk · 确认" height={620}>
    {"\n"}
    <S c={V4.fg}>  以下 </S><S c={V4.green} b>3 项</S><S c={V4.fg}> 将被清理：</S>{"\n\n\n"}

    <S c={V4.cyan} b>  ·  开发工具缓存</S>{"\n"}
    {"       "}<S c={V4.yellow}>  2.6G</S>{"     "}<S c={V4.fg}>gopls / goimports 缓存</S>{"\n\n"}

    <S c={V4.cyan} b>  ·  应用数据</S><S c={V4.dim}>（慎清）</S>{"\n"}
    {"       "}<S c={V4.yellow}>  6.7G</S>{"     "}<S c={V4.fg}>壁纸缓存</S><S c={V4.dim}>（macOS 自动重建）</S>{"\n\n"}

    <S c={V4.cyan} b>  ·  GVM</S><S c={V4.dim}>（旧 Go 版本）</S>{"\n"}
    {"       "}<S c={V4.yellow}> 46.2G</S>{"     "}<S c={V4.fg}>go1.16</S>  <S c={V4.dim}>gos+pkgsets · gvm uninstall</S>{"\n\n\n"}

    {"                       "}<S c={V4.fg}>预计释放</S> <S c={V4.green} b>55.5 GiB</S>{"\n\n\n"}

    {"       "}<S c={V4.dim}>[ 返回修改 ]</S>
    {"          "}
    <S c={V4.green} b>▸ [ 开始清理 ]</S>{"\n\n\n"}

    <S c={V4.dim}>  ← → 切换    Enter 确认    q 返回</S>{"\n"}
  </V4Frame>
);

/* ── 7 · 清理中 ──────────────────────────────────────────────── */
const V4_Execute = () => (
  <V4Frame title="cleanup-disk" height={380}>
    {"\n"}
    <S c={V4.fg}>  正在清理 </S><S c={V4.green} b>3 项</S><S c={V4.fg}>…</S>{"\n\n"}
    <S c={V4.green}>  ✓  </S><S c={V4.dim}>1/3  </S><S c={V4.fg}>gopls / goimports 缓存</S>{"\n"}
    <S c={V4.green}>  ✓  </S><S c={V4.dim}>2/3  </S><S c={V4.fg}>壁纸缓存</S>{"\n"}
    <S c={V4.cyan}>  ⠹  </S><S c={V4.dim}>3/3  </S><S c={V4.fg}>go1.16</S>{"\n"}
  </V4Frame>
);

/* ── 8 · 完成 ────────────────────────────────────────────────── */
const V4_Done = () => (
  <V4Frame title="cleanup-disk" height={460}>
    {"\n"}
    <S c={V4.green} b>  ✓ </S>
    <S c={V4.fg}>清理完成，本次释放约 </S>
    <S c={V4.green} b>55.2G</S>
    <S c={V4.fg}>。</S>{"\n\n"}
    <DiskV4 free="165Gi" used="271Gi" total="460Gi" pct="62%" />{"\n\n\n"}
    <S c={V4.dim}>  提示：移到废纸篓的文件需在 Finder 清空废纸篓后</S>{"\n"}
    <S c={V4.dim}>       才会真正腾出空间。</S>{"\n"}
  </V4Frame>
);

/* ── 9 · 已取消 ──────────────────────────────────────────────── */
const V4_Cancel = () => (
  <V4Frame title="cleanup-disk" height={200}>
    {"\n\n"}
    <S c={V4.dim}>  已取消，未执行任何清理。</S>{"\n"}
  </V4Frame>
);

Object.assign(window, {
  V4_ScanIntro, V4_Scan, V4_Menu, V4_MenuOverflow, V4_Buttons,
  V4_Empty, V4_Confirm, V4_Execute, V4_Done, V4_Cancel,
});
