---
title: "Git 命令速查 — 从发布博客学 Git"
description: "以发布博客笔记/文章为场景，系统梳理 Git 常用命令"
date: 2026-08-15
tags: [git, blog, workflow]
type: note
topic: "Git"
---


## 1. 先看发布流程

### 方式 A：脚本

```powershell
# 新增笔记：-Type note 收录到 /notes，按 -Topic 分组
.\UPDATE.ps1 .\notes\git-cheatsheet.md -Type note -Topic "Git" -Tags git,blog
# 新增文章：默认 article，进首页「最新文章」
.\UPDATE.ps1 .\posts\xxx.md -Tags cpp,learning
# 只更新已有文章（直接改了 src/content/blog/*.md 后）
.\UPDATE.ps1
```

脚本执行完整流程：生成 frontmatter → 复制到 `src/content/blog/` → `npm run build` 验证 → **commit → push** → GitHub Actions 自动部署。

### 方式 B：手动 Git

```bash
# 1. 编辑/新建文章：src/content/blog/xxx.md
# 2. 看改了什么
git status
git diff
# 3. 暂存 + 提交
git add src/content/blog/xxx.md
git commit -m "post: xxx"
# 4. 推送 → 触发部署
git push origin main
```

## 2. Git 模型

```
工作区(磁盘文件) ──git add──> 暂存区(staging) ──git commit──> 本地仓库 ──git push──> 远端(origin/main)
```

| 概念 | 是什么 | 相关命令 |
|---|---|---|
| 工作区 | 磁盘上的实际文件 | 直接编辑 |
| 暂存区 | 准备好要提交的改动清单 | `git add` |
| 本地仓库 | 提交历史 | `git commit` |
| 远端 | GitHub 上的副本 | `git push` / `git pull` |

## 3. 常用命令分类速查

### 3.1 查看状态

```bash
git status                   # 工作区/暂存区状态，最常用
git status -sb               # 简写 + 当前分支 + 本地领先/落后远端几个提交
git log --oneline            # 简洁提交历史（每条一行）
git log --oneline --graph    # 带分支图
git diff                     # 看工作区未暂存的改动
git diff --staged            # 看已暂存（即将提交）的改动
git log origin/main..main    # 本地有、远端没有的提交（检查是否忘推送）
```

### 3.2 提交改动

```bash
git add <file>             # 把某个文件加入暂存区
git add -u                 # 加入已跟踪文件的改动（不含新文件）
git add -A                 # 加入所有改动（含新文件）
git add src/content/blog/  # 加入某个目录
git commit -m "post: xxx"  # 提交，-m 写信息
git commit -am "msg"       # 对「已跟踪」文件 = add + commit 一步到位（新文件仍需先 add）
```

### 3.3 撤销与修正

```bash
git restore <file>            # 丢弃工作区改动（回到上次提交）
git restore --staged <file>   # 取消暂存（文件改动保留）
git reset --soft HEAD~1       # 撤销最近一次提交，改动保留在暂存区
git reset --hard HEAD~1       # 撤销提交并丢弃改动（危险！）
git revert <commit>           # 生成一个反向新提交来撤销（适合已推送的情况）
git commit --amend            # 修改上一条提交的信息（别改已推送的提交）
```

### 3.4 分支

```bash
git branch               # 列出本地分支
git checkout -b feature  # 新建并切换到 feature 分支
git switch feature       # 切换到已有分支
git merge feature        # 把 feature 合并进当前分支
git branch -d feature    # 删除已合并的分支
```

### 3.5 远端

```bash
git remote -v         # 查看远端地址
git clone <url>       # 克隆远端仓库到本地
git fetch             # 只拉取远端信息，不合并
git pull origin main  # 拉取并合并（= fetch + merge）
git push origin main  # 推送本地提交到远端
```

### 2.6 fork与PR
```bash
git remote add upstream <url>  # 添加上游仓库
git fetch upstream              # 拉取上游仓库信息
git merge upstream/main         # 合并上游 main 分支到本地
git fork <url>                     # 在 GitHub 上 fork 仓库
```

## 4. 发一篇笔记

```bash
# ① 新建 src/content/blog/git-cheatsheet.md 并写内容

# ② 确认改了哪些文件
git status

# ③ 提交
git add src/content/blog/git-cheatsheet.md
git commit -m "post: git-cheatsheet"

# ④ 确认会推上去哪些提交（防止忘推）
git log origin/main..main --oneline

# ⑤ 推送 → GitHub Actions 自动构建部署
git push origin main
```

## 5. 常见问题排查

| 现象 | 原因 | 处理 |
|---|---|---|
| 线上没更新 | 本地有提交没 push | `git log origin/main..main` 查看，然后 `git push origin main` |
| push 被拒绝 | 远端有新提交，本地落后 | `git pull origin main` 再 `git push` |
| 提交信息写错 | — | `git commit --amend` 修改 |
| add 错了文件 | — | `git restore --staged <file>` |
| 改乱某个文件 | — | `git restore <file>`（会丢改动，确认后执行） |

## 6. 本仓库的约定

- 主分支：`main`；GitHub Actions 在 push 到 main 时自动构建部署
- 提交信息风格：`post: 标题`（文章）、`fix:`（修复）、`feat:`（功能）、`chore:`（杂项）
- 文章文件名 = URL slug，只用英文/数字/连字符
- 用 `.\UPDATE.ps1` 发布最省事，它会自动完成 add / commit / push
