# Lilly Blog — 静态博客设计

- 日期:2026-08-07
- 状态:已批准(brainstorming 逐节确认)
- 目录:`E:\ReactLearn\lilly-blog`(独立于现有 `self blog` 全栈项目)

## 1. 目标

在 `E:\ReactLearn\lilly-blog` 新建一个**纯静态个人博客**,复用现有全栈博客(`self blog`)的设计与内容资产,免费托管到 GitHub Pages。

## 2. 范围(含排除项)

**包含:**
- 页面:首页(文章列表 + hero)、文章详情、About
- 文章:3 篇 Markdown(复制自 `E:\LearnProgramming\cpp\project\CPGA calculate\`)
- 随机莫奈背景 dissolve(每页随机 1-2 张,复用现有视觉)

**排除(用户明确取消):**
- 后端 / 数据库 / API
- GitHub OAuth 登录
- 评论、搜索、标签、统计
- 画廊整页(用户因图片多、加载慢取消)

## 3. 技术栈

- **Astro 5**(静态生成,Markdown Content Collections)
- **Tailwind CSS 4**(迁移现有 `@theme` token)
- 无 React 框架(保持加载轻量);交互用原生 JS + CSS
- 动效:复用现有 `motionTokens` 的节奏(简化为 CSS transitions + reduced-motion 支持)

## 4. 页面与路由

| 路由 | 页面 | 内容 |
|------|------|------|
| `/` | 首页 | 简介 hero + 文章列表(复用 `.card` 卡片样式) |
| `/post/[slug]` | 文章详情 | Markdown 渲染 + 文章元信息(日期/标签) |
| `/about` | About | 简介 + Music/Art/Game 折叠区(复用现有文案) |
| `404` | 未找到 | 兜底页 |

## 5. 内容

- `src/content/blog/`:3 篇文章(带 frontmatter:title / date / tags / summary):
  - `BLOG.md` → 《用 Claude Code 和一个小项目,从零学会 C++》(tags: cpp, learning)
  - `TUTORIAL.md` → 《CGPA 计算器 — C++ 项目教程》(tags: cpp, tutorial)
  - `TEACHING_PROMPT.md` → 《AI 教学提示词模板》(tags: ai, learning)
- `public/` 静态资源:
  - `OIP.webp`(头像)
  - `about/*.webp`(莫奈背景图,随机背景池)

## 6. 设计复用(完全)

- 从 `self blog/index.css` 迁移 `@theme` token:bg/card/text/heading/border/accent(暗/亮两套)
- 复用 `.card` 卡片样式、暗色切换(localStorage + `prefers-color-scheme`)
- 随机莫奈背景 + 过渡(dissolve),首屏只加载当前随机的一张
- 动效节奏对齐现有 `motionTokens`;`prefers-reduced-motion` 下降级

## 7. 部署

- 新 GitHub 仓库:`xiaobin118/lilly-blog`
- GitHub Pages **项目站点**:Astro 配 `base: '/lilly-blog/'`
- 发布方式:push 到 master 后由 GitHub Actions 构建并部署到 Pages(或手动)

## 8. 数据流

- **构建时**:Astro 读取 Content Collections → 生成静态 HTML/CSS/JS
- **运行时**:无 API 请求;文章、列表、About 内容均为构建产物

## 9. 错误处理

- 未知 slug → 返回 404 页
- 图片加载失败 → 背景回退到 `bg-dark` token 色
- 文章内容为空 → 显示占位提示

## 10. 测试

- `npm run build` 通过(类型 + 构建)
- 本地 `npm run preview` 逐页验证:首页列表、3 篇详情、About、暗色切换、随机背景、reduced-motion

## 11. 待用户手动完成

- 在 GitHub 创建空仓库 `lilly-blog`(我负责建目录、写代码、推送)
