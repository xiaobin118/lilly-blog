# Projects 页 — 内容模块化设计

- 日期：2026-11-17
- 状态：待主人审查
- 前置：brainstorming 三轮确认（项目=组织单元 / 项目页=长文+汇总 / 双通道可见性）

## 1. 目标

给博客加一个**项目层**：把「同一个目标下的一组文章/笔记」收拢到一个可浏览的单元里，而不是让所有内容平铺在 `/notes` 和首页里。

成功标准：

1. 打开 `/projects` 能一眼看到做过哪些项目、各自几篇、状态如何。
2. 进入某个项目能读到它的介绍，并直接看到它下面的全部文章（自动生成，不手写）。
3. 写一篇新笔记时，只在 frontmatter 加一行 `project: <id>` 就能归到某个项目，不必移动文件。
4. 现有 7 篇内容不受影响（双通道：仍然出现在首页/Notes/归档）。

## 2. 内容职责规则（本设计的契约）

| 类型 | 负责 | 不负责 | 判定标准 | 例子 |
|---|---|---|---|---|
| **project** | 范围、目标、技术栈、里程碑、结果、外部链接，以及「这个项目下有哪些文章」的目录 | 单个知识点的推导、环境命令细节、代码逐行讲解 | 有起止、有交付物、能独立跑起来 | 机器学习实验三：k-means + GMM |
| **note** | 一个知识点 / 速查表 / 复盘，脱离上下文也能读 | 项目整体叙述、选型决策 | 只回答一个「为什么 / 怎么做」 | EM 算法推导、NumPy 函数速查 |
| **article** | 有主线、有开头结尾的叙事或教程 | 单点速查、项目汇总 | 需要从头读到尾才成立 | 用 Claude Code 从零学 C++ |

四条硬规则：

1. **一条内容只有一个主归属**：文章/笔记最多挂一个项目（`project` 单值）；项目不挂项目。
2. **项目页是唯一目录**：项目下的文章列表由构建期自动生成，禁止手写列表；顺序由 `date` 决定。
3. **职责不重叠**：项目正文写「为什么做、做到什么程度、结果如何」；笔记写「知识点本身」。环境搭建、目录结构、踩坑史属于项目，不进笔记。
4. **升级时机**：同类笔记攒到 3 篇以上且共享同一目标才建项目；1 篇笔记不要建项目。

一句话：**项目管「做成了什么」，笔记管「学会了什么」，文章管「怎么讲给人听」。**

## 3. 数据模型

### 3.1 新集合 `projects`

文件：`src/content/projects/<id>.md`，文件名即 URL slug（`^[a-z0-9-]+$`）。

```yaml
---
title: 机器学习实验三：k-means 与 GMM
description: 纯 NumPy 手写 k-means 与 EM，对比 BIC 与轮廓系数
date: 2026-10-13        # 排序与展示用
status: done            # done | doing | planned
tech: [Python, NumPy]
repo: https://github.com/xiaobin118/ml-exp3   # 可选
---
（项目介绍正文，Markdown；不要再写 `# 标题`，标题由布局渲染）
```

schema（`src/content.config.ts` 新增）：

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
```

### 3.2 blog 集合新增关联字段

```ts
project: z.string().optional(),
```

同时从 blog 的 `type` 枚举里**移除 `project`**（项目的唯一来源是 projects 集合，避免两套定义；当前 7 篇内容没有用到该值，删除无副作用）。

## 4. 关联与校验

- 文章的 `project` 值必须等于某个项目文件的 id。
- 校验放在构建期：`src/lib/projects.ts` 暴露 `assertKnownProjects(entries, projectIds)`；`/projects/index.astro` 与项目详情页在构建时调用，遇到未知 id 直接抛错并列出文件路径。
  - 理由：静默忽略会留下「这篇为什么不在项目里」的幽灵问题，构建期报错定位最快。
- 项目页的文章列表：`getCollection('blog').filter(p => p.data.project === project.id)`，按 `date` 倒序。

## 5. 路由与页面

| 路由 | 内容 |
|---|---|
| `/projects/` | 项目卡片列表（按 date 倒序）：标题、description、status 徽章、tech 标签、`N 篇文章`、最后更新日期 |
| `/projects/[slug]/` | 项目正文（Markdown）+ 页尾「项目文章」列表（复用 `ArticleCard`） |

- 项目页**不重复渲染 h1**：标题由布局输出，正文里不许再写 `#`。
- 实现阶段先建 1 个示例项目 `src/content/projects/ml-exp3-kmeans-gmm.md`（正文 2–3 段，status: done，tech: Python/NumPy），用于验证列表、详情与关联；真实项目内容由主人后续补充。
- v1 **不做** TOC、阅读进度条（项目页是导航页，不是长文阅读场景）；需要再加。
- 列表页空状态：「还没有项目」；项目下无文章：「这个项目还没有关联文章」。

## 6. 视觉与背景

- 页面沿用现有 `.page` / `.card` / `.section-title` / `.tag` 体系，不引入新组件样式。
- status 徽章用 `.tag` 变体：`done` 绿调、`doing` 琥珀（accent）、`planned` 灰调；只在 `global.css` 加三个 `.badge-*` 类。
- **背景**：`/projects` 使用主人提供的《日出·印象》——`public/image/projects/3-莫奈-日出印象.webp`（1600×1217，474KB），接入 `Background.astro` 的 `projectsImages` 池；其余页面背景不变。

## 7. 导航、搜索、RSS

- `Navbar` 增加 `Projects`，位置在 `Archive` 之后（`About` 之前）。
- URL 生成统一：新增 `src/lib/urls.ts` 的 `entryUrl(entry)`——blog 条目 → `${base}post/<id>/`，project 条目 → `${base}projects/<id>/`。现有 `ArticleCard`、`archive`、`search-index.json` 里硬编码的 `/post/${id}` 改为调用它。
- 搜索索引同时收录项目（title/description/tech 作为 tags 字段），URL 走 `entryUrl`；命令面板对 `type: project` 显示 🗂 图标。
- RSS 只保留 article/note，项目页不进 feed。

## 8. 边界与错误处理

- `project` 字段指向不存在的 id → 构建失败，错误信息包含文件名与非法 id。
- 项目文件名不合 slug 规则 → 不做特殊处理（沿用 Astro id 生成），但在文档里约定小写连字符。
- `repo` 非 URL → schema 校验失败（构建期）。
- 删除某个项目文件时，其下文章仍保留 `project` 字段 → 触发第 4 节校验失败，强制作者处理（改指向或清空），避免静默变成「无归属」。

## 9. 测试

1. `npm run build` 通过，页数 = 25 + 1（`/projects/`）+ N（项目页数量，示例阶段 N=1）。
2. `/projects/` 返回 200，卡片含文章计数；项目详情页只列出 `project` 匹配的文章，且按日期倒序。
3. 临时把某篇文章的 `project` 改成 `nope`，构建必须失败并指出该文件；验证后还原。
4. 搜索 `实验` 能命中项目页，URL 为 `/projects/...`。
5. 移动端 390px 无横向溢出，状态徽章与 tech 标签换行正常。

## 10. 非目标（YAGNI）

- 不做项目内文件树 / 提交历史 / GitHub API 实时拉取。
- 不做多项目归属、不做项目嵌套。
- 不改首页布局（入口只在导航栏）。
- 不迁移现有 7 篇内容；ML 笔记若要重新发布，按「1 个项目 + N 篇带 `project` 的文章」组织，而不是平铺进 `/notes`。

## 11. 迁移与清理（已完成部分）

- 29 篇 ml-/dl- 笔记、`network_structure.md`、`src/content/blog/ml-assets/`（25 张图）已删除并提交（`e21c5ba`）。
- 背景图已放入 `public/image/projects/`，待实现时接入。

## 12. 决策记录

- 项目=组织单元（非纯展示、非单纯筛选）。
- 项目页=介绍长文+自动汇总。
- 双通道可见：关联项目的文章仍出现在首页/归档/Notes。
- 入口只在导航栏（首页/侧栏不动）。
