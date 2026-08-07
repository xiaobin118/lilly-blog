---
title: "AI 教学提示词模板"
description: "可复用的 AI 增量教学 prompt 模板"
date: 2026-08-07
tags: [ai, learning]
---

# AI 教学提示词模板

将这个 prompt 用于其他项目，AI 会像这个 CGPA 计算器项目一样，一步步教你。

---

## 使用方法

1. 把下面的 prompt 复制到 Claude Code 或其他 AI 工具
2. 把 `[项目名称]` 和 `[项目描述]` 替换成你的项目
3. 把 `[你的背景]` 替换成你的实际情况

---

## Prompt（英文版，适用于大部分 AI）

```
I am a C++ learner. My background: [你的背景，例如: I know C, Python, CSAPP, and basic C++ grammar].

I want to learn by building a project: **[项目名称]**.

Project description: [项目描述，例如: A CGPA Calculator that computes cumulative GPA from course grades and credits.]

Requirements:
1. Teach me in Chinese.
2. Do NOT write all the code at once. Instead, guide me step by step — each step teaches ONE new concept.
3. For each step:
   a. Explain the new concept briefly (compare with C/Python if applicable)
   b. Give me a small, specific coding task
   c. After I write the code, review it and point out errors
   d. After fixing errors, move to the next step
4. Start simple and refactor/upgrade as we go (e.g. struct → class → multi-file → features).
5. Let me struggle a bit with errors — they are learning opportunities. Don't fix everything upfront.
6. Connect every new C++ concept to what I already know from C and Python.
7. The final project should be complete and functional, covering: C++ classes, STL containers (vector, map), file I/O, algorithms (sort, find), multi-file compilation.
```

---

## Prompt（中文版）

```
我是一个 C++ 初学者。我的背景：[你的背景]。

我想通过构建一个项目来学习：**[项目名称]**。

项目描述：[项目描述]

教学要求：
1. 用中文教学。
2. 不要一次性写完所有代码。每一步只教一个新概念，让我自己动手写。
3. 每一步的流程：
   a. 先解释新概念（可以和 C/Python 对比）
   b. 给我一个具体的、小范围的编码任务
   c. 我写完代码后，帮我 review，指出错误
   d. 修改完毕后，进入下一步
4. 从最简单的版本开始，逐步重构升级（比如 struct → class → 多文件 → 加功能）。
5. 允许我犯错误——错误是学习机会。不要在一开始就把所有坑都填好。
6. 把每个 C++ 新概念联系到我已会的 C 和 Python 知识。
7. 最终项目应该完整可用，覆盖：类、STL 容器、文件 I/O、算法、多文件编译。
```

---

## 教学方法的要点

如果你是自己教别人，或者想让 AI 以这种风格教你，以下是关键原则：

### 1. 增量构建
- ❌ 一次性给出 6 个文件的完整代码
- ✅ 从 `struct` + `main()` 一个文件开始，逐步拆分为 class、多文件

### 2. 每个错误都是教学机会
- 不要提前警告所有陷阱（比如"传引用"问题）
- 让学生先犯错，看到错误信息，再解释为什么错、怎么修
- 错误信息本身就是重要的调试技能

### 3. 联系已有知识
- "这和 C 的 `FILE*` 一样，但更安全"
- "这相当于 Python 的 `dict`"
- "引用就是不能为空的指针"

### 4. 先解释为什么，再展示怎么做
- 不要只说"加 const"
- 要说"加 const 后，如果你不小心在只读方法里修改了数据，编译器会直接报错——这就是把 bug 从运行时提前到编译期"

### 5. 让学生动手写
- 给任务描述，不给完整代码
- 给代码骨架，让学生填充关键部分
- 每步写完都要 review

### 6. 做一个真正可用的东西
- 不要停留在玩具示例
- 最终产物应该是可以运行、可以展示的完整程序

---

## 适用项目类型

这种"增量教学"方法特别适合：

| 项目类型 | 示例 |
|---------|------|
| 命令行工具 | 计算器、文件管理器、TODO 列表 |
| 数据管理 | 学生管理系统、图书管理系统 |
| 小游戏 | 猜数字、贪吃蛇、井字棋 |
| 算法练习 | 排序可视化、路径查找 |
| 网络工具 | HTTP 客户端、聊天程序 |

---

## 示例：如果用这个 prompt 开始一个新项目

假设你想学数据结构，做一个"学生成绩管理系统"：

```
我是一个 C++ 初学者。背景：学过 C 和 Python，懂基本 C++ 语法。

我想通过构建项目学习：学生成绩管理系统。

项目描述：管理学生信息和考试成绩，支持添加学生、录入成绩、
计算平均分、排名、数据持久化。

教学要求：（同上）
```

AI 可能会这样开始：
1. 第一步：用 struct 表示一个学生
2. 第二步：用 class 封装，加入成绩计算
3. 第三步：用 vector 管理多个学生
4. 第四步：拆分多文件
5. 第五步：交互菜单
6. 第六步：文件存取
7. 第七步：排序（按总分排名）+ 搜索（按姓名查找）
