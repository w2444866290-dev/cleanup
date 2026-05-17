# docs/ui — Whisper UI 设计文档

cleanup-disk 的 CLI / TUI 设计资料都放在这里。一篇 markdown 规范 + 一组浏览器视觉对照。

## 文件

| 文件 | 用途 |
|---|---|
| [`ui.md`](ui.md) | **设计规范**（zh-CN）—— 颜色 / 字符 / 布局常量、每屏渲染函数、键位、验收清单。改 UI 先来这里。 |
| `Whisper - Refined.html` | **视觉对照页**。React + Babel-standalone 在浏览器里实时渲染所有屏幕的 mock，方便直观对照设计意图与代码实现。 |
| `design-canvas.jsx` | 画布框架：`DesignCanvas` / `DCSection` / `DCArtboard`。 |
| `terminal.jsx` | 终端样式原语：`TermFrame` 边框 + `S` 着色 span。 |
| `option-a-tokens.jsx` | 「设计语言」3 屏：色板、字符、主菜单解剖。 |
| `option-a-whisper.jsx` | v3 视觉存档 10 屏 + 共享的 `A_COLORS` 调色板（被 tokens / v4 通过 `window.A_COLORS` 引用）。 |
| `option-a-v4.jsx` | v4（即当前实现）视觉 10 屏：扫描 / 主菜单 / 按钮四态 / confirm / execute / done / cancel / empty。 |

## 打开视觉对照页

HTML 里的 `<script src="*.jsx">` 是相对路径，并且 `text/babel` 需要 fetch jsx 文本来编译。直接 `file://` 打开会被浏览器的 CORS 拦掉，要起一个静态 HTTP 服务：

```bash
cd docs/ui
python3 -m http.server 8000 --bind 127.0.0.1
# 浏览器开
open "http://127.0.0.1:8000/Whisper%20-%20Refined.html"
```

页面三栏：

1. **设计语言** —— 色板 / 字符 / 主菜单解剖
2. **完整状态图 · v3** —— 视觉存档，留作对照参考
3. **完整状态图 · v4 (中文母语版)** —— 对应当前 `ui.md` 与 `lib/*.sh` 实现

## 改 UI 的工作流

1. 改 `ui.md` 里相应章节的渲染函数 / 输出示例。
2. 同步改 `lib/*.sh` 里的实现（spec 章节号一般和源码注释对得上）。
3. 在真实终端跑 `./cleanup-disk.sh`（TUI 无法用管道或后台测）。
4. 想看「应该长什么样」时打开 HTML 视觉对照页；想看「现在长什么样」就跑脚本。

## 依赖关系（jsx 加载顺序）

HTML 里 `<script>` 顺序是关键 —— `option-a-whisper.jsx` 必须先于 tokens / v4 加载，因为它在末尾把调色板挂到 `window.A_COLORS` 上：

```
design-canvas.jsx
  └── terminal.jsx
        └── option-a-whisper.jsx     ← 末尾 Object.assign(window, { A_COLORS: A, ... })
              ├── option-a-tokens.jsx ← const A = window.A_COLORS
              └── option-a-v4.jsx     ← const V4 = window.A_COLORS
```

加新的 design 模块时如果要复用调色板，沿用 `window.A_COLORS` 即可；HTML 里的脚本顺序按上面这个 DAG 维持。
