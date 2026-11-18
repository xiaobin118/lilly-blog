# Lilly Blog

基于 **Astro 5 + Tailwind CSS 4** 的纯静态个人博客,复用全栈版博客(`self-blog`)的设计与莫奈背景,免费托管在 GitHub Pages。

## 页面

- `/` 首页:文章列表 + 随机莫奈背景
- `/archive` 归档:年份时间线
- `/post/[slug]` 文章详情
- `/about` 关于

## 本地开发

```bash
npm install
npm run dev      # 开发(默认 http://localhost:4321/lilly-blog/)
npm run build    # 构建到 dist/
npm run preview  # 预览构建产物
```

## 发布 / 更新文章

文章为 Markdown,存放在 `src/content/blog/*.md`(文件名即 URL slug)。

**发布（TUI 菜单）:**

```powershell
.\UPDATE.ps1     # Windows
./UPDATE.sh      # Linux / WSL
```

- 新文章 / 笔记：选 `.md` 文件，脚本补 `title/date/tags/type/topic/project`（已有 frontmatter 则保留）
- 已有改动：勾选要发布的 blog / project 文件，只 `git add` 选中的
- 构建验证 → commit → push；构建失败不会提交

## 部署

push 到 `main` 后,GitHub Actions 自动构建并发布到 GitHub Pages:

`https://xiaobin118.github.io/lilly-blog/`
