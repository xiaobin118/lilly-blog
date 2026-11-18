# 内容发布规则（rule.md）

本文件是**内容发布的唯一契约**。任何 agent 在新增或修改文章、笔记、项目页之前，必须先读本文件，按这里的判定与格式执行；与本文件冲突的临时指示，先向用户确认再动手。

适用范围：`src/content/blog/*.md`、`src/content/projects/*.md`。页面/组件代码改动看 [AGENTS.md](AGENTS.md)。

---

## 1. 先判定类型（三问）

按顺序问，命中即停：

1. 它描述一个**有起止、有交付物、能独立跑起来**的东西吗？→ `project`
2. 它**只回答一个**「为什么 / 怎么做」，脱离上下文也能读吗？→ `note`
3. 它需要**从头读到尾**讲一个完整故事或教程吗？→ `article`

| 类型 | 负责 | 不负责 | 例子 |
|---|---|---|---|
| project | 范围、目标、技术栈、里程碑、结果、外部链接，以及「这个项目下有哪些文章」的目录 | 单点推导、环境命令细节、逐行代码讲解 | 机器学习实验三：k-means + GMM |
| note | 一个知识点 / 速查表 / 复盘 | 项目整体叙述、选型决策 | EM 算法推导、NumPy 函数速查 |
| article | 有主线、有开头结尾的叙事或教程 | 单点速查、项目汇总 | 用 Claude Code 从零学 C++ |

一句话：**项目管「做成了什么」，笔记管「学会了什么」，文章管「怎么讲给人听」。**

四条硬规则：

1. 一条内容只有一个主归属：文章/笔记最多挂一个项目（`project` 单值）；项目不挂项目。
2. 项目页是唯一目录：项目下的文章列表**自动生成**，禁止手写；顺序由 `date` 决定。
3. 职责不重叠：项目正文写「为什么做、做到什么程度、结果如何」；笔记写「知识点本身」。
4. 升级时机：同类笔记攒到 **3 篇以上**且共享同一目标才建项目；1 篇笔记不要建项目。

**不确定类型时先问用户，不要猜。**

---

## 2. 落盘位置与命名

| 内容 | 路径 |
|---|---|
| 文章 / 笔记 | `src/content/blog/<slug>.md` |
| 项目 | `src/content/projects/<id>.md` |
| 图片 | 内容文件旁边的同名目录（见第 5 节） |

- `slug` / `id` 必须匹配 `^[a-z0-9-]+$`（小写字母、数字、连字符），**它就是 URL**：`/post/<slug>/`、`/projects/<id>/`。
- 中文标题不能直接当文件名；用英文语义化 slug（`ml-em-algorithm`、`git-blog-workflow`）。
- note 与 project 的标题不要带数字编号，比如「机器学习实验3 kmeans与gmm」应直接写「kmeans 与 gmm」。
- 一个文件一篇内容。**正文里不许再写 `# 标题`**——标题由 frontmatter 提供、布局统一渲染，否则页面会出现两个标题。

---

## 3. frontmatter

### 3.1 文章 / 笔记（`src/content/blog/`）

```yaml
---
title: 用 Claude Code 从零学 C++
description: 用「项目 + AI 助手」的方式学一门新语言，以及踩过的坑
date: 2026-08-07
tags: [learning, ai]        # 必须 ASCII，见下方说明
type: article               # article | note | research（默认 article）
topic: "C++"                # 仅 note 用；/notes 按它分组
project: ml-exp3-kmeans-gmm # 可选：所属项目 id，最多一个
---
```

- `title`、`date` 必填；`description` 强烈建议（用于卡片与搜索结果）。
- `type` 只允许 `article | note | research`——**项目不是这里的类型**，项目走第 3.2 节的独立集合。
- `tags` **必须全 ASCII**：`slugifyTag()` 会把非 `[a-z0-9+]` 的字符清成 `-`，中文标签会变成空字符串并生成 `/tags//` 死链。标签要写 `machine-learning` 而不是「机器学习」。
- `date` 用 `YYYY-MM-DD`；同一天多篇时按文件顺序排序，不建议。

### 3.2 项目（`src/content/projects/`）

```yaml
---
title: k-means 与 GMM
description: 纯 NumPy 手写 k-means 与 EM，不依赖 scipy / sklearn
date: 2026-10-13
status: done                # done | doing | planned（默认 doing）
tech: [Python, NumPy]       # 卡片上显示为标签，允许非 ASCII
repo: https://github.com/... # 可选，必须是合法 URL
---
```

- 项目正文写介绍（2–5 段），不写 `#` 标题，不复制笔记内容。
- `tech` 为空时不显示标签；`repo` 省略时不显示仓库链接。
- 项目 id = 文件名，被文章用 `project: <id>` 引用。

---

## 4. 文章 → 项目的关联

- 在文章 frontmatter 加 `project: <项目 id>`，一篇文章最多一个。
- 项目页的文章列表由 `project === id` 自动筛选、按 `date` 倒序，**不要手写列表**。
- 校验在构建期：指向不存在的 id 时 `npm run build` 失败，错误信息会给出可用项目列表和出错文件，例如：

  ```
  Unknown project reference(s). Available projects: kmeans-gmm
    - git-blog-workflow: project "does-not-exist"
  ```

  看到这个错误就改文章或先建项目，不要忽略、不要在代码里加 try/catch 绕过。
- 删除项目文件前，先清空或改指向它下面文章的 `project` 字段，否则构建失败（这是故意的）。

---

## 5. 图片与公式

**图片**（走 Astro 内容管线，构建时自动转 webp 并压缩）：

- 目录与引用（同目录同名）：

  ```
  src/content/blog/<slug>.md
  src/content/blog/<slug>/fig01.png        ← 引用 ![](./<slug>/fig01.png)
  src/content/projects/<id>.md
  src/content/projects/<id>/arch.png       ← 引用 ![](./<id>/arch.png)
  ```

- **不要**把正文图片放进 `public/image/`：那样不经过压缩，也不会随内容移动。
- `alt` 必填（描述图的内容，不是「图片」）。

**公式**（remark-math + KaTeX）：

- 行内：`\(...\)`
- 显示公式必须三行式，`$$` 与公式各占一行，前后留空行：

  ```
  $$
  \ln p(X \mid \theta) = \sum_{n=1}^{N} \ln \left( \sum_{k=1}^{K} \pi_k \mathcal{N}(x_n \mid \mu_k, \Sigma_k) \right)
  $$
  ```

- 禁止 `$$公式$$` 写在同一行：会被当作行内公式，排版塌掉。
- 长公式要主动断行：`$$` 内单行源码超过约 90 个字符，或顶层 `+`、`=` 超过 4 个时，用 `\begin{aligned}` 在 `=`、`+` 处换行。KaTeX 不会自动换行，超宽公式会溢出卡片；页面有横向滚动兜底，但滚动条不是可接受的阅读方式。
- 公式里出现中文时包在 `\text{...}` 里。

---

## 6. 发布流程

1. 写/改内容文件（按 2–5 节）。
2. `npm run build` —— **必须通过**，失败就修内容，不要绕过。
3. 发布（TUI，按菜单操作）：
   - Windows：`.\UPDATE.ps1`
   - Linux / WSL：`./UPDATE.sh`
   - 菜单选「发布新文章 / 笔记」或「发布已有 blog / project 改动」；脚本会构建验证 → 只 `git add` 选中的文件 → `commit` → `push origin main`。
   - 只验证构建：`.\UPDATE.ps1 -Check` / `./UPDATE.sh --check`。
4. 脚本会：构建验证 → `git add` → `commit` → `push origin main` → GitHub Actions 部署。
5. **构建失败时脚本会中止，不会 commit/push**；不要手工跳过这步直接 `git push`。

只提交内容时，commit message 用 `post: <标题>`；新增功能用 `feat:`；修复用 `fix:`。

---

## 7. Agent 行为契约

- 先读本文件 → 判定类型 → 写文件 → 构建 → 修问题 → 提交；每次只做一类内容。
- 不修改与本次内容无关的文件（页面代码、样式、脚本）。
- **不要批量灌入未整理的草稿**：一次性导入 30 篇无结构笔记后全部被删除过；先确认类型与归属，再落盘。
- 生成的内容必须向用户回报：类型、slug、最终 URL、是否已 push。
- 用户给的规则与本文件冲突时，以用户当次明确指示为准，并同步更新本文件。

---

## 8. 发布前检查表

- [ ] 类型判定有理由，且符合第 1 节
- [ ] slug 合规、全站唯一
- [ ] frontmatter 字段齐全；`tags` 全 ASCII；`date` 格式正确
- [ ] 标题不要带数字编号
- [ ] 正文没有 `#` 标题
- [ ] 图片用 `./<slug>/` 相对路径，且 `alt` 非空
- [ ] 显示公式是三行式
- [ ] 长公式已用 `aligned` 断行（单行源码 > 90 字符或顶层运算符 > 4 个）
- [ ] 关联的 `project` 存在（或已决定不关联）
- [ ] `npm run build` 通过
- [ ] 提交信息符合 `post:` / `feat:` / `fix:`
