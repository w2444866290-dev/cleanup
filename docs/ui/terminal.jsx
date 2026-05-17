/* Shared terminal frame + color helpers */

const TermFrame = ({ width = 720, height = 520, title = "", children, bg = "#0d0d10", chrome = "#1a1a1d", chromeFg = "#7d7d85", style = {} }) => (
  <div style={{
    width, height,
    background: bg,
    borderRadius: 10,
    overflow: "hidden",
    fontFamily: '"JetBrains Mono", "SF Mono", ui-monospace, Menlo, Consolas, monospace',
    fontSize: 13,
    lineHeight: 1.55,
    color: "#e6e6e6",
    display: "flex",
    flexDirection: "column",
    boxShadow: "0 1px 0 rgba(255,255,255,.04) inset, 0 18px 40px -20px rgba(0,0,0,.6)",
    ...style,
  }}>
    <div style={{
      height: 26, background: chrome, display: "flex", alignItems: "center",
      padding: "0 12px", gap: 6, flexShrink: 0,
      borderBottom: "1px solid rgba(255,255,255,.04)",
    }}>
      <span style={{ width: 10, height: 10, borderRadius: "50%", background: "#ff5f57" }} />
      <span style={{ width: 10, height: 10, borderRadius: "50%", background: "#febc2e" }} />
      <span style={{ width: 10, height: 10, borderRadius: "50%", background: "#28c840" }} />
      <span style={{ marginLeft: 14, fontSize: 11, color: chromeFg, letterSpacing: 0.2 }}>{title}</span>
    </div>
    <pre style={{
      margin: 0, padding: "16px 20px", flex: 1, whiteSpace: "pre",
      overflow: "hidden", fontFeatureSettings: '"liga" 0',
    }}>
      {children}
    </pre>
  </div>
);

// span helpers
const S = ({ c, b, children, bg, style }) => (
  <span style={{ color: c, fontWeight: b ? 700 : 400, background: bg, ...style }}>{children}</span>
);

Object.assign(window, { TermFrame, S });
