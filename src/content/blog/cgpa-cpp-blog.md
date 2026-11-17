---
title: "用 Claude Code 和一个小项目，从零学会一门新语言（c++）"
description: "用'项目 + AI 助手'的方式学 C++，以及踩过的坑"
date: 2026-08-07
tags: [learning, ai tutorial]
---

> 这篇博客记录了我用"项目 + AI 助手"的方式学 C++ 的过程，以及过程中踩过的坑。

## 开始之前

我学过 C、Python，也读过 CSAPP，C++ 的基本语法大概了解，但没写过完整的项目。这一次，我决定直接做一个 CGPA 计算器（累计绩点计算器），让 Claude Code 当我的指导，边写边学。

目标：管理多个学期的课程信息、计算 GPA 和 CGPA、数据保存到文件、支持搜索和排序。

## 怎么教，定了个规则

开始前我先和 Claude 约定了教学方式：

- 不要一次性写完所有代码
- 每一步只教一个新概念
- 让我自己动手写，写完它来 review
- 报错先让我自己看，再帮我分析

这个约定很重要。如果它直接把六个文件都写好，我就只能抄一遍，什么都学不到。

## 学习过程

### 第一步：用 struct 表示一门课程

在 `main.cpp` 里写一个 `struct Course`，包含课程名、学分、成绩三个字段，创建一门课打印出来。编译运行，先跑通一个文件。

### 第二步：struct 升级成 class

把 `struct` 改成 `class`，成员变量放进 `private`，加上 getter 和构造函数。

这一步立刻报错：

```
No member named 'name' in 'Course'
```

因为成员变量变私有了，外部访问不了。解决办法是加 getter 方法：

```cpp
class Course {
public:
    Course(const std::string& name, double credits, const std::string& grade) {
        m_name = name;
        m_credits = credits;
        m_grade = grade;
    }
    const std::string& getName() const { return m_name; }
private:
    std::string m_name;
    double m_credits;
    std::string m_grade;
};
```

### 第三步：成绩字母转绩点

加一个 `getGradePoint()`，把 "A" 转成 4.0、"B+" 转成 3.3 这样。用 `std::map` 做映射，比写一串 if-else 干净：

```cpp
const std::map<std::string, double> GRADE_MAP = {
    {"A", 4.0}, {"A-", 3.7}, {"B+", 3.3}, ...
};

double Course::getGradePoint() const {
    auto it = GRADE_MAP.find(m_grade);
    if (it != GRADE_MAP.end()) {
        return it->second;
    }
    return 0.0;
}
```

### 第四步：算质量点

GPA 公式：质量点 = 学分 × 绩点，GPA = 所有质量点之和 / 总学分。

```cpp
double Course::getQualityPoints() const {
    return getCredits() * getGradePoint();
}
```

用 `std::vector<Course>` 存多门课，范围 for 循环遍历求和。

### 第五步：拆多文件

项目开始变大，把 Course 拆成 `course.h`（声明）+ `course.cpp`（实现）。编译命令变成：

```powershell
g++ -std=c++17 src/main.cpp src/course.cpp -I include -o main.exe
```

这一步报了整整一排链接错误：

```
undefined reference to `Course::getCredits() const'
undefined reference to `Course::getName() const'
undefined reference to `Course::getGrade() const'
```

原因：头文件里声明了这些方法，但 `.cpp` 里只实现了三个，剩下的三个没写实现。链接器拼程序的时候找不到它们的定义。补上实现就好了。

这让我真正理解了声明和定义的区别，以及 C++ 的编译链接流程：每个 `.cpp` 独立编译成目标文件，最后链接器拼装。

### 第六步：交互式菜单

用 `do-while` + `switch` 做一个循环菜单，用户选择操作。加课程、显示课程、算 GPA、退出。

踩了一个坑：`switch` 的 fall-through。某个 `case` 结尾忘了写 `break`，结果选"显示课程"会把 GPA 也一起算出来。补上 `break` 就好了。

还有个输入坑：`std::cin >> x` 会把回车留在缓冲区，后面的 `getline` 直接读到空串，表现为"输入被跳过"。解决方法是 `cin >> x` 之后加一句 `std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n')`。

Windows 上还有中文乱码问题，在 `main()` 开头加：

```cpp
SetConsoleOutputCP(65001);
```

### 第七步：Semester 类

把多个学期的课程组织起来。`Semester` 类包含课程名和 `vector<Course>`，方法有 `addCourse`、`calculateGPA`、`printReport` 等。

这里踩了一个隐藏 bug：函数参数传值 vs 传引用。我写的菜单函数把 `vector<Course>` 按值传进去，函数里加的课程加在副本上，返回后全丢了。改成引用 `std::vector<Semester>&` 就好了。

### 第八步：CGPA（累计绩点）

CGPA 是跨所有学期的：所有学期的质量点之和 ÷ 总学分。给 `Semester` 加 `getTotalQualityPoints()` 方法，然后在菜单里累加。

注意 CGPA 不能把各学期 GPA 相加——那会超过 4.0。

### 第九步：文件存储

用 `std::ofstream` / `std::ifstream` 把数据保存到磁盘，退出程序再打开还能加载回来。

课程要能序列化成一行的字符串，从字符串恢复：

```cpp
// 序列化：对象 → "Calculus,4.000000,A"
std::string Course::serialize() const {
    return m_name + "," + std::to_string(m_credits) + "," + m_grade;
}

// 反序列化：字符串 → 对象
Course Course::deserialize(const std::string& line) {
    size_t pos1 = line.find(',');
    std::string name = line.substr(0, pos1);
    // ... 解析学分和成绩
}
```

文件格式：第一行学期名，之后每行一门课。

### 第十步：搜索和排序

用 `std::find_if` 按名称搜索课程，用 `std::sort` 按成绩排序。两者都用 lambda 指定条件：

```cpp
// 搜索
auto it = std::find_if(m_courses.begin(), m_courses.end(),
    [&name](const Course& c) { return c.getName() == name; });

// 排序
std::sort(m_courses.begin(), m_courses.end(),
    [](const Course& a, const Course& b) {
        return a.getGrade() < b.getGrade();
    });
```

`findCourse` 返回指针：找到返回 `&(*it)`，没找到返回 `nullptr`。

## 踩过的坑汇总

| 坑 | 现象 | 解决 |
|----|------|------|
| `undefined reference` | 链接报错 | `.cpp` 里漏了实现 |
| switch fall-through | 选一个功能执行了多个 | 每个 case 末尾加 `break` |
| cin 缓冲区残留 | getline 跳过输入 | `cin >> x` 后加 `cin.ignore()` |
| 传值 vs 传引用 | 函数里改的数据丢了 | 参数加 `&` |
| Windows 中文乱码 | 输出乱码 | `SetConsoleOutputCP(65001)` |
| `#include <windows.h>` 报错 | 和 `numeric_limits::max()` 冲突 | 先 `#define NOMINMAX` |

## 完成后的感受

从单文件 struct 一路做到多文件、多学期、带文件存储的完整工具，中间每个报错都变成了学习材料。最后程序能存数据、能加载、能搜索排序的时候，很有成就感。

整个过程最值得借鉴的一点：**让 AI 一步步给你小任务，自己动手写，写错了再一起分析，而不是让它把整个项目一次性写出来。**

我把这次的教学方式整理成了[一个可复用的 prompt 模板](../ai-teaching-prompt/)，下次做别的项目可以直接用：

```
不要一次性写完所有代码，每一步只教一个新概念，让我自己动手写，
写完帮我 review，遇到报错先让我自己看再帮我分析。
```

## 项目产物

- `include/` + `src/`：完整的 Course、Semester、main 代码
- `TUTORIAL.md`：分步教程，每个知识点配代码和讲解
- [AI 教学提示词模板](../ai-teaching-prompt/)：可复用的 AI 教学 prompt（原 `TEACHING_PROMPT.md`）
