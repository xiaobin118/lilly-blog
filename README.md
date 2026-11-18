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

**新增文章:**

```powershell
.\UPDATE.ps1 .\path\to\article.md -Tags cpp,learning
```

- 文件名需为英文/数字/连字符(用作 URL)
- 无 frontmatter 时自动补 `title/date/tags`
- 自动构建验证 → 提交 → 推送部署

**更新已有文章**(直接编辑 `src/content/blog/*.md` 后):

```powershell
.\UPDATE.ps1
```

自动检测改动 → 构建验证 → 提交 → 推送。

## 部署

push 到 `main` 后,GitHub Actions 自动构建并发布到 GitHub Pages:

`https://xiaobin118.github.io/lilly-blog/`
