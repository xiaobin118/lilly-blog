# Projects 页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增加项目层：`/projects` 列表 + `/projects/[slug]` 详情，文章通过 frontmatter `project` 关联，项目页自动汇总。

**Architecture:** 新内容集合 `projects` 与现有 `blog` 并列；blog 增加可选 `project` 字段。页面复用现有 `.page/.card/.tag/.section-title/ArticleCard`，不新建视觉体系。构建期校验非法 `project` 引用。

**Tech Stack:** Astro 5 content collections、TypeScript、Tailwind CSS 4。

**Spec:** `docs/superpowers/specs/2026-11-17-projects-page-design.md`

## Global Constraints

- 项目文件：`src/content/projects/<id>.md`，id 小写连字符（`^[a-z0-9-]+$`）。
- 项目 frontmatter：`title`、`description`、`date`、`status: done|doing|planned`（默认 `doing`）、`tech: string[]`（默认 `[]`）、`repo?: url`。
- 项目正文**不得**再写 `# 标题`（标题由布局渲染）。
- 文章/笔记最多挂 1 个项目：blog schema 的 `project?: string`。
- 项目下的文章列表自动生成、按 `date` 倒序；禁止手写列表。
- 双通道：关联项目的文章仍出现在首页/归档/Notes。
- 入口只在导航栏（首页/侧栏不改）。
- `/projects` 背景：`public/image/projects/3-莫奈-日出印象.webp`。
- 未知 `project` 引用 → 构建失败，错误信息含文章文件名与非法值。
- RSS 不收项目（projects 是独立集合，rss 保持只读 blog，无需改动）。

## Review Focus

- 文章指向不存在/已删除的项目 → 必须构建失败，而不是静默消失在项目页。
- 项目下 0 篇文章 → 详情页显示「这个项目还没有关联文章」，不报错。
- 项目详情 URL 在 base `/lilly-blog/` 下带尾斜杠，且不误匹配 `/projects` 列表页。
- 搜索索引里的项目 URL 必须指向 `/projects/<id>/`，不能落到 `/post/<id>/`。
- `tech` 为空或 `status` 缺省时，卡片与详情页不渲染空标签/空徽章。

---

### Task 1: 内容模型与示例项目

**Files:**
- Modify: `src/content.config.ts`
- Create: `src/content/projects/ml-exp3-kmeans-gmm.md`

**Interfaces:**
- Produces: 集合 `projects`，条目字段 `{ title, description, date, status, tech, repo? }`；blog 条目新增 `data.project?: string`。
- Produces: 示例项目 id `ml-exp3-kmeans-gmm`（后续任务用它验证）。

- [ ] **Step 1: 在 `src/content.config.ts` 增加 projects 集合**

```ts
const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    date: z.coerce.date(),
    status: z.enum(['done', 'doing', 'planned']).default('doing'),
    tech: z.array(z.string()).default([]),
    repo: z.string().url().optional(),
  }),
});
export const collections = { blog, projects };
```

同时：blog schema 增加 `project: z.string().optional()`；`type` 枚举改为 `['article', 'note', 'research']`。

- [ ] **Step 2: 创建示例项目 `src/content/projects/ml-exp3-kmeans-gmm.md`**

frontmatter 用上表字段（`date: 2026-10-13`、`status: done`、`tech: [Python, NumPy]`、不写 `repo`）；正文写 2–3 段：目标（纯 NumPy 手写 k-means 与 EM，不用 scipy/sklearn）、实现范围、结论（定性描述，不抄具体数值）。正文不写 `#` 标题。

- [ ] **Step 3: 验证**

Run: `npm run build`
Expected: 通过；页数仍为 25（尚未新增路由）。

- [ ] **Step 4: Commit**

```bash
git add src/content.config.ts src/content/projects
git commit -m "feat(projects): add projects collection and schema"
```

---

### Task 2: URL 与校验辅助函数

**Files:**
- Create: `src/lib/urls.ts`
- Create: `src/lib/projects.ts`

**Interfaces:**
- Produces: `postUrl(id: string): string`、`projectUrl(id: string): string`（均带 `import.meta.env.BASE_URL` 前缀与尾斜杠）。
- Produces: `countByProject(entries: { data: { project?: string } }[]): Map<string, number>`。
- Produces: `assertKnownProjects(entries: { id: string; data: { project?: string } }[], known: Set<string>): void`，未知时 `throw new Error(...)`，消息含 `entry.id` 与非法值。

- [ ] **Step 1: 写 `src/lib/urls.ts`**

```ts
const base = import.meta.env.BASE_URL;
export const postUrl = (id: string) => `${base}post/${id}/`;
export const projectUrl = (id: string) => `${base}projects/${id}/`;
```

- [ ] **Step 2: 写 `src/lib/projects.ts`**

`countByProject` 遍历 entries，忽略无 `project` 的条目；`assertKnownProjects` 收集所有非法引用后一次性抛出（消息里逐条列出 `文件 id → 值`），无非法引用时返回。

- [ ] **Step 3: 验证**

Run: `npm run check`
Expected: 0 errors（函数暂未被引用，只验类型）。

- [ ] **Step 4: Commit**

```bash
git add src/lib/urls.ts src/lib/projects.ts
git commit -m "feat(projects): add url and project-reference helpers"
```

---

### Task 3: 项目列表页（含背景与导航）

**Files:**
- Create: `src/components/ProjectCard.astro`
- Create: `src/pages/projects/index.astro`
- Modify: `src/components/Navbar.astro`（`navItems` 增加 Projects，位于 Archive 之后）
- Modify: `src/components/Background.astro`（新增 `projectsImages` 池，匹配 `projects` 与 `projects/<slug>`）
- Modify: `src/styles/global.css`（`.tag-done` / `.tag-doing` / `.tag-planned` 三个徽章样式）

**Interfaces:**
- Consumes: `projectUrl`, `countByProject`（Task 2）。
- Produces: 组件 `ProjectCard` props `{ project: CollectionEntry<'projects'>; count: number }`。

- [ ] **Step 1: `ProjectCard.astro`**

复用 `.card` + `.stretched-link`；显示 title、description（`line-clamp-2`）、状态徽章（`tag tag-{status}`，`planned`/`doing`/`done` 文案分别为「规划中/进行中/已完成」）、tech 标签、`{count} 篇文章`、日期。`count === 0` 时不渲染文章数。

- [ ] **Step 2: `pages/projects/index.astro`**

`getCollection('projects')` 按 `date` 倒序；`getCollection('blog')` → `countByProject`；空态「还没有项目」；用 `.page` + `.section-title`。

- [ ] **Step 3: 导航与背景**

Navbar：`{ href: `${base}projects/`, label: 'Projects' }` 插在 Archive 之后。Background：新增池并让 `clean === 'projects' || clean.startsWith('projects/')` 命中。

- [ ] **Step 4: 验证**

Run: `npm run build`（Expected: 26 页）
Run: `curl -s -o NUL -w "%{http_code}" http://localhost:4321/lilly-blog/projects/`（先 `npm run preview`）
Expected: 200，HTML 含「机器学习实验三」。

- [ ] **Step 5: Commit**

```bash
git add src/components/ProjectCard.astro src/pages/projects/index.astro src/components/Navbar.astro src/components/Background.astro src/styles/global.css
git commit -m "feat(projects): add projects index page and navigation entry"
```

---

### Task 4: 项目详情页

**Files:**
- Create: `src/pages/projects/[slug].astro`

**Interfaces:**
- Consumes: `postUrl`、`ProjectCard` 不需要；复用 `ArticleCard`。
- Produces: 路由 `/projects/<id>/`。

- [ ] **Step 1: 实现页面骨架**

`getStaticPaths` 返回 `{ params: { slug: p.id }, props: { project: p } }`；`render(project)` 渲染正文；头部：title、status 徽章、tech 标签、`repo`（有则显示外链）、日期；正文后用 `prose` 容器。

- [ ] **Step 2: 文章列表与空态**

`getCollection('blog').filter(p => p.data.project === project.id)` 按 `date` 倒序，`ArticleCard` 渲染；为空时显示「这个项目还没有关联文章」。

- [ ] **Step 3: 验证**

Run: `npm run build`（Expected: 27 页，新增 `/projects/ml-exp3-kmeans-gmm/`）
Run: `curl` 该详情页，Expected: 200 且含项目标题与空态文案。

- [ ] **Step 4: 临时验证关联**

把 `src/content/blog/git-blog-workflow.md` 的 frontmatter 加一行 `project: ml-exp3-kmeans-gmm`，重新 build + curl 详情页，Expected: 列表出现该文章；确认后删除该行并重新 build。

- [ ] **Step 5: Commit**

```bash
git add src/pages/projects/[slug].astro
git commit -m "feat(projects): add project detail page with aggregated articles"
```

---

### Task 5: 搜索与 URL 统一

**Files:**
- Modify: `src/pages/search-index.json.ts`
- Modify: `src/components/CommandPalette.astro`
- Modify: `src/components/ArticleCard.astro`、`src/pages/archive.astro`、`src/pages/post/[slug].astro`

**Interfaces:**
- Consumes: `postUrl`, `projectUrl`（Task 2）。

- [ ] **Step 1: search-index 收录项目**

`getCollection('projects')` 追加条目：`type: 'project'`、`tags: tech`、`url: projectUrl(id)`；blog 条目 `url` 改用 `postUrl(id)`。

- [ ] **Step 2: 命令面板图标**

两处 `r.type === 'note' ? '📝' : '📄'` 改为包含 `project → '🗂'`。

- [ ] **Step 3: 替换硬编码 URL**

`ArticleCard`、`archive.astro`、`post/[slug].astro` 相关文章里的 `` `${base}post/${...}/` `` 改为 `postUrl(...)`（保留尾斜杠写法一致）。

- [ ] **Step 4: 验证**

Run: `npm run build`；`curl http://localhost:4321/lilly-blog/search-index.json`，Expected: 含 `"url":"/lilly-blog/projects/ml-exp3-kmeans-gmm/"` 与 `"type":"project"`。

- [ ] **Step 5: Commit**

```bash
git add src/pages/search-index.json.ts src/components/CommandPalette.astro src/components/ArticleCard.astro src/pages/archive.astro "src/pages/post/[slug].astro"
git commit -m "feat(search): index projects and unify entry urls"
```

---

### Task 6: 构建期校验与收尾

**Files:**
- Modify: `src/pages/projects/index.astro`

**Interfaces:**
- Consumes: `assertKnownProjects`（Task 2）。

- [ ] **Step 1: 接入校验**

`pages/projects/index.astro` 顶部：`const ids = new Set(projects.map(p => p.id)); assertKnownProjects(posts, ids);`。

- [ ] **Step 2: 验证失败路径**

临时把某篇文章的 `project` 改成 `does-not-exist`，`npm run build`，Expected: 失败，错误信息同时出现该文章文件名与 `does-not-exist`；还原后 build 通过。

- [ ] **Step 3: 最终验证**

Run: `npm run check` → 0 errors；`npm run build` → 27 页。
Run: 预览后 `curl /projects/` 与 `/projects/ml-exp3-kmeans-gmm/` 均 200。

- [ ] **Step 4: Commit**

```bash
git add src/pages/projects/index.astro
git commit -m "feat(projects): fail the build on unknown project references"
```
