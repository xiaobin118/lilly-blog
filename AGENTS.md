# lilly-blog

Astro 5 + Tailwind CSS 4 静态博客（TypeScript），部署在 GitHub Pages 的 /lilly-blog/。不是 React。

## 命令
- `npm run check` — astro 类型检查
- `npm run build` / `npm run dev` — 构建 / 开发
- `.\UPDATE.ps1` — 发布：自动 frontmatter（+ `-Type note -Topic "C++"`）、构建、commit、push
- `git push origin main` — 触发 GitHub Actions 部署；只 commit 不 push，线上不会更新

## 内容
- 文章/笔记在 `src/content/blog/*.md`；文件名 = URL slug（仅英文/数字/连字符）
- Schema 有 `type`（article|note|project|research，默认 article）+ `topic`；笔记进 /notes 按主题分组
- LaTeX 数学：`$...$` / `$$...$$` 经 KaTeX 渲染（remark-math + rehype-katex）

## 关键坑
- ClientRouter 视图过渡会替换 DOM：组件脚本只运行一次。所有交互 JS 必须用 document 级事件委托或在 `astro:page-load` 重跑（主题切换、折叠、搜索过滤、命令面板、代码复制）。导航会抹掉 `.dark` 类——需在 `astro:page-load` 重新应用主题。
- 禁止 `<a>` 嵌套 `<a>`（卡片链接包标签链接）：浏览器会自动闭合外层锚点。用 `.stretched-link` 模式（relative 卡片 + 标题链接 ::after 覆盖 + 内层链接 `relative`）。
- Chrome DevTools MCP 不稳定——浏览器不可用时用 `dist/` HTML + `npm run check` 验证。
- 当前模型看不了图片——设计参考用 `Codex-vision-skill`（vision.js）。

## 设计
- 暖色纸感亮色主题：bg #f1efe7、card #fbfbfb、accent #a129e6；暗色 #16171d
- 组件类：`.card`、`.tag`（淡紫）、`.section-title`、`.page` 容器
- 首页/文章页两栏布局（侧边栏：搜索/热门标签/关于/项目；文章 TOC）
