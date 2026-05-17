/* Whisper — design tokens reference cards */

const A = window.A_COLORS;

/* Card 1 — palette */
const A_Palette = () => {
  const items = [
    { name: "fg",     hex: "#e8e6e1", ansi: "\\033[38;5;253m", use: "primary text" },
    { name: "dim",    hex: "#5a5a62", ansi: "\\033[2m",         use: "secondary, hints, dividers" },
    { name: "faint",  hex: "#7a7a83", ansi: "\\033[38;5;243m", use: "kicker labels" },
    { name: "green",  hex: "#a3c986", ansi: "\\033[38;5;108m", use: "success, free space, selected" },
    { name: "yellow", hex: "#d8a657", ansi: "\\033[38;5;179m", use: "sizes, time, warnings" },
    { name: "red",    hex: "#ea6962", ansi: "\\033[38;5;167m", use: "errors, failures" },
    { name: "cyan",   hex: "#89b482", ansi: "\\033[38;5;108m", use: "category headers, spinner" },
    { name: "blue",   hex: "#7daea3", ansi: "\\033[38;5;109m", use: "optional info accent" },
  ];
  return (
    <div style={{
      width: 720, height: 540,
      background: A.bg,
      color: A.fg,
      fontFamily: '"JetBrains Mono", monospace',
      fontSize: 12,
      padding: "28px 32px",
      boxSizing: "border-box",
      borderRadius: 10,
    }}>
      <div style={{ color: A.faint, marginBottom: 4 }}>cleanup-disk</div>
      <div style={{ fontSize: 18, marginBottom: 24, color: A.fg }}>palette · whisper</div>
      <div style={{ display: "grid", gridTemplateColumns: "120px 60px 1fr 1fr", gap: "10px 16px", fontSize: 11.5 }}>
        <div style={{ color: A.dim }}>name</div>
        <div style={{ color: A.dim }}>swatch</div>
        <div style={{ color: A.dim }}>ansi (256-color)</div>
        <div style={{ color: A.dim }}>use</div>
        {items.map((it) => (
          <React.Fragment key={it.name}>
            <div style={{ color: A.fg }}>{it.name}</div>
            <div style={{ height: 16, background: it.hex, borderRadius: 3 }} />
            <div style={{ color: A.fg }}>{it.ansi}</div>
            <div style={{ color: A.dim }}>{it.use}</div>
          </React.Fragment>
        ))}
      </div>
      <div style={{ color: A.dim, marginTop: 22, fontSize: 11, lineHeight: 1.6 }}>
        notes ·  upgrade from 8-color ansi; falls back to <span style={{color: A.fg}}>\033[31m</span>-family<br/>
        ·  saturation kept ≤ 0.10 so colors read as "warm dim" instead of neon<br/>
        ·  only one accent (green) is used as the focus / action color throughout
      </div>
    </div>
  );
};

/* Card 2 — glyphs */
const A_Glyphs = () => {
  const rows = [
    ["▸",      "row cursor",     "green, bold",  "focus on list" ],
    ["◯ / ●",   "checkbox",       "dim / green",  "unselected / selected"],
    ["›",      "action arrow",   "follow button","inside Clean-now button"],
    ["·",      "kicker separator","dim",         "between title and subtitle"],
    ["·",      "category bullet","cyan, bold",   "left of category names (confirm)"],
    ["─",      "thin divider",   "dim",          "count line + confirm summary frame"],
    ["━",      "progress bar",   "green / dim",  "filled / empty"],
    ["⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏","spinner",  "cyan",          "shown after 2s on slow scans"],
    ["✓ / ✗",   "result mark",    "green / red",  "execute & done lines"],
    ["⌃C",     "key hint",       "dim",          "shown alone for cancel"],
  ];
  return (
    <div style={{
      width: 720, height: 540,
      background: A.bg, color: A.fg,
      fontFamily: '"JetBrains Mono", monospace',
      fontSize: 12,
      padding: "28px 32px",
      boxSizing: "border-box",
      borderRadius: 10,
    }}>
      <div style={{ color: A.faint, marginBottom: 4 }}>cleanup-disk</div>
      <div style={{ fontSize: 18, marginBottom: 24, color: A.fg }}>glyphs · whisper</div>
      <div style={{ display: "grid", gridTemplateColumns: "140px 1fr 1fr 1.4fr", gap: "10px 14px", fontSize: 11.5 }}>
        <div style={{ color: A.dim }}>char</div>
        <div style={{ color: A.dim }}>name</div>
        <div style={{ color: A.dim }}>color</div>
        <div style={{ color: A.dim }}>where</div>
        {rows.map((r, i) => (
          <React.Fragment key={i}>
            <div style={{ color: A.green, fontSize: 14 }}>{r[0]}</div>
            <div style={{ color: A.fg }}>{r[1]}</div>
            <div style={{ color: A.dim }}>{r[2]}</div>
            <div style={{ color: A.dim }}>{r[3]}</div>
          </React.Fragment>
        ))}
      </div>
      <div style={{ color: A.dim, marginTop: 22, fontSize: 11, lineHeight: 1.6 }}>
        replaced from original spec ·  <span style={{color: A.fg}}>▶ → ▸</span> ·{" "}
        <span style={{color: A.fg}}>[ ]/[✓] → ◯/●</span> ·{" "}
        <span style={{color: A.fg}}>➜ → ›</span> ·{" "}
        <span style={{color: A.fg}}>= → ─</span> (single, thin)
      </div>
    </div>
  );
};

/* Card 3 — anatomy of the main menu */
const A_Anatomy = () => (
  <div style={{
    width: 720, height: 600,
    background: A.bg, color: A.fg,
    fontFamily: '"JetBrains Mono", monospace',
    fontSize: 12,
    padding: "28px 32px",
    boxSizing: "border-box",
    borderRadius: 10,
    position: "relative",
  }}>
    <div style={{ color: A.faint, marginBottom: 4 }}>磁盘清理</div>
    <div style={{ fontSize: 18, marginBottom: 18, color: A.fg }}>主菜单解剖 · 各区高度与着色规则</div>

    <pre style={{ margin: 0, fontSize: 12, lineHeight: 1.55, fontFamily: 'inherit', position: "relative", color: A.fg }}>
{`  磁盘清理  ·  选择要清理的项              `}<span style={{color: A.yellow}}>① kicker (1 行)</span>{`

  总容量 460Gi  ·  已用 326Gi  ·  可用 `}<span style={{color: A.green}}>110Gi</span>{`  ·  占用 75%       `}<span style={{color: A.yellow}}>② disk strip (1 行)</span>{`


  `}<span style={{color: A.green, fontWeight: 700}}>开发工具缓存·3</span>{`     应用缓存·3     应用数据·2     …       `}<span style={{color: A.yellow}}>③ tabs (2 行)</span>{`
  `}<span style={{color: A.green}}>──────────────</span>{`

  `}<span style={{color: A.dim}}>…其余 2 项 ↑</span>{`                                       `}<span style={{color: A.yellow}}>④ 上溢出指示 (1 行)</span>{`
  `}<span style={{color: A.green, fontWeight: 700}}>▸</span>{`   `}<span style={{color: A.dim}}>◯</span>{`     `}<span style={{color: A.yellow}}>2.6G</span>{`     gopls / goimports 缓存           `}<span style={{color: A.yellow}}>⑤ rows ≤7 (可变)</span>{`
      `}<span style={{color: A.dim}}>◯</span>{`     `}<span style={{color: A.yellow}}>2.4G</span>{`     npm 缓存 (~/.npm)
      `}<span style={{color: A.green}}>●</span>{`     `}<span style={{color: A.yellow}}>2.8G</span>{`     Yarn 缓存
  `}<span style={{color: A.dim}}>…其余 1 项 ↓</span>{`                                       `}<span style={{color: A.yellow}}>⑥ 下溢出指示 (1 行)</span>{`

  `}<span style={{color: A.dim}}>──────────────────────────────────────  共 11 项</span>{`     `}<span style={{color: A.yellow}}>⑦ count (1 行)</span>{`

      `}<span style={{color: A.green, fontWeight: 700}}>开始清理  ›  已选 1 项 · 2.8G</span>{`        `}<span style={{color: A.yellow}}>⑧ button (1 行)</span>{`


  `}<span style={{color: A.dim}}>← → 切 tab   ↑↓ 移动   空格 勾选   …</span>{`             `}<span style={{color: A.yellow}}>⑨ keys (1 行)</span>{`
`}
    </pre>

    <div style={{ position: "absolute", bottom: 22, left: 32, right: 32, color: A.dim, fontSize: 11, lineHeight: 1.6 }}>
      规则 · 所有行首 2 空格 gutter · 同区块不留空、区块间空 1 行、主区与顶/底空 2 行 ·
      不用 <span style={{color: A.fg}}>=</span> / <span style={{color: A.fg}}>---</span> 做结构线 ·
      列表上下固定预留 1 行作溢出指示，保证整体高度稳定
    </div>
  </div>
);

Object.assign(window, { A_Palette, A_Glyphs, A_Anatomy });
