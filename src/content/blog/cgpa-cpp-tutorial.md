---
title: "CGPA 计算器 — C++ 项目教程"
description: "通过构建 CGPA 计算器从零学习 C++ 核心知识"
date: 2026-08-07
tags: [cpp, tutorial]
---

# CGPA 计算器 — C++ 项目教程

## 项目简介

通过构建一个 **CGPA（累计绩点）计算器**，从零开始学习 C++ 的核心知识。

CGPA 计算器能做什么：
- 管理多个学期的课程信息
- 计算单学期 GPA 和累计 CGPA
- 将数据保存到文件，下次启动时加载
- 搜索课程、按成绩排序

**适合人群**：有 C 和 Python 基础，了解基本 C++ 语法的学习者。

---

## 你将学到的 C++ 知识点

| 知识点 | 在哪里用到 |
|--------|-----------|
| `class` / 封装 (`public` `private`) | Course、Semester 类 |
| 构造函数与初始化列表 | `Course(...)` `Semester(...)` |
| `const` 正确性 | getter 方法、const 成员函数 |
| `std::map` | 成绩字母 → 绩点映射 |
| `std::vector` | 存储课程列表 |
| 多文件编译 (`.h` + `.cpp`) | include/ 和 src/ 目录结构 |
| 文件 I/O (`std::ofstream` / `std::ifstream`) | 保存/加载数据 |
| 序列化与反序列化 | `serialize()` / `deserialize()` |
| `std::sort` + lambda 表达式 | 按成绩排序 |
| `std::find_if` + lambda 表达式 | 按名称搜索课程 |
| 指针与引用 | `const Course*` 返回值、`const string&` 参数 |
| 范围 for 循环 | `for (const auto& c : courses)` |

---

## 项目结构

```
CPGA calculate/
├── include/
│   ├── course.h          ← Course 类的声明
│   └── semester.h        ← Semester 类的声明
├── src/
│   ├── course.cpp        ← Course 类的实现
│   ├── semester.cpp      ← Semester 类的实现
│   └── main.cpp          ← 程序入口 + 交互菜单
├── data/                 ← 存放保存的数据文件
├── compile_flags.txt     ← clangd 配置
└── TUTORIAL.md           ← 本教程
```

---

## 第一步：用 struct 表示一门课程

### 学到的知识

C++ 中 `struct` 和 C 的 `struct` 用法相似——把相关的数据打包在一起。

### 代码

```cpp
#include <iostream>
#include <string>

struct Course {
    std::string name;
    double credits;
    std::string grade;
};

int main() {
    Course c1{"Calculus", 4.0, "A"};
    std::cout << "课程: " << c1.name
        << ", 学分: " << c1.credits
        << ", 成绩: " << c1.grade << std::endl;
    return 0;
}
```

### 编译

```powershell
g++ -std=c++17 main.cpp -o main.exe
```

---

## 第二步：从 struct 升级到 class

### 学到的知识

C++ 中 `struct` 和 `class` 几乎一样，**唯一的区别是默认访问权限**：


| --- | `struct` | `class`|
|---|---|---|
| 默认访问权限 | `public` | `private` |

用 `class` + `private` 可以把数据藏起来，只有通过公开的接口（getter）才能访问。这就是**封装（Encapsulation）**。

### 关键概念：构造函数

构造函数和类同名，没有返回值。创建对象时自动调用，保证对象一出生就有合法的初始状态。

```cpp
class Course {
public:
    Course(const std::string& name, double credits, const std::string& grade) {
        m_name = name;
        m_credits = credits;
        m_grade = grade;
    }

    const std::string& getName()   const { return m_name; }
    double             getCredits() const { return m_credits; }
    const std::string& getGrade()  const { return m_grade; }

private:
    std::string m_name;
    double      m_credits;
    std::string m_grade;
};
```

### 关键概念：const 成员函数

```cpp
const std::string& getName() const { return m_name; }
//                            ↑
//              这个 const = "我承诺不修改任何成员变量"
```

- 不加 const = 可能修改数据的方法（如 setter、addCourse）
- 加 const = 只读方法（如 getter、calculateGPA、printReport）

### 关键概念：const 引用参数

```cpp
Course(const std::string& name, ...)
//     ^^^^^^^^  ^^^^^^^  ^
//     不拷贝    不修改   别名（vs 指针：不能为空、语法更简洁）
```

| | `const std::string&` (引用) | `const std::string*` (指针) |
|---|---|---|
| 可以为空 | 不能 | 可以 (`nullptr`) |
| 使用语法 | `name.length()` | `name->length()` |
| 安全性 | 编译器保证非空 | 必须手动检查 |

---

## 第三步：成绩字母 → 绩点转换

### 学到的知识

`std::map` — C++ 的键值对容器，和 Python 的 `dict` 一样。

```cpp
#include <map>

const std::map<std::string, double> GRADE_MAP = {
    {"A", 4.0}, {"A-", 3.7}, {"B+", 3.3}, {"B", 3.0}, {"B-", 2.7},
    {"C+", 2.3}, {"C", 2.0}, {"C-", 1.7}, {"D+", 1.3}, {"D", 1.0}, {"F", 0.0}
};

double Course::getGradePoint() const {
    auto it = GRADE_MAP.find(m_grade);    // 查找
    if (it != GRADE_MAP.end()) {         // 找到了
        return it->second;               // it->first = key, it->second = value
    }
    return 0.0;                          // 没找到（无效成绩）
}
```

### 关键概念：auto 关键字

`auto it = ...` — 让编译器自动推导类型。这里 `it` 的类型是 `std::map<std::string, double>::const_iterator`，你不用手写这一长串。

---

## 第四步：计算质量点（Quality Points）

### 学到的知识

GPA 的核心公式：

```
Quality Points（质量点） = 学分 × 绩点
GPA = Σ(质量点) / Σ(学分)
```

例如：Calculus（4 学分，A = 4.0）→ 质量点 = 4.0 × 4.0 = 16.0

```cpp
double Course::getQualityPoints() const {
    return getCredits() * getGradePoint();
}
```

用 `std::vector<Course>` 存储多门课，用范围 for 循环遍历：

```cpp
double calculateGPA(const std::vector<Course>& courses) {
    double totalQP = 0.0, totalCredits = 0.0;
    for (const auto& course : courses) {             // 范围 for 循环
        totalQP += course.getQualityPoints();        // 分子
        totalCredits += course.getCredits();          // 分母
    }
    return (totalCredits == 0) ? 0.0 : totalQP / totalCredits;
}
```

---

## 第五步：多文件编译

### 学到的知识

C++ 的编译模型和 Python 完全不同：

```
Python:   import course        → 解释器直接加载 course.py
C++:      #include "course.h"  → 预处理器把 course.h 的内容复制粘贴到这里
```

C++ 编译三步：
1. **预处理**：展开 `#include`、`#define`
2. **编译**：每个 `.cpp` 独立编译成 `.o`（目标文件）
3. **链接**：把所有 `.o` 合并成一个可执行文件

```
course.h  ──┐
├──→ 预处理 → 编译 → course.o ──┐
course.cpp ─┘                                ├──→ 链接 → main.exe
main.cpp ────────────────────→ main.o ───────┘
```

**头文件 (.h)** = 声明/接口 —— "这个类有哪些方法"
**源文件 (.cpp)** = 实现/定义 —— "这些方法具体怎么做"

### 编译多文件

```powershell
g++ -std=c++17 src/main.cpp src/course.cpp -I include -o main.exe
```

- `-I include`：告诉编译器去 `include/` 目录找头文件
- 用双引号 `"course.h"` 包含自己的头文件，用尖括号 `<string>` 包含标准库头文件

### 注意：声明 vs 定义

```cpp
// course.h —— 声明：告诉编译器"这个函数存在"
double getCredits() const;

// course.cpp —— 定义：告诉编译器"这个函数做什么"
double Course::getCredits() const {
    return m_credits;
}
```

> `Course::` 双冒号是作用域解析运算符，表示"这是 Course 类的方法"。在 .h 里不需要写（因为在类的大括号内部），在 .cpp 里必须写。

### 重要：匿名命名空间

```cpp
namespace {
const std::map<...> GRADE_MAP = { ... };
}
```

匿名命名空间 = 这个变量**只在本文件内可见**（相当于 C 的 `static`）。放在 `.cpp` 里，不让其他文件访问。

### clangd 配置

创建 `compile_flags.txt` 告诉 clangd（代码编辑器）头文件在哪里：

```
-std=c++17
-Iinclude
```

---

## 第六步：交互式菜单

### 学到的知识

`do-while` 循环（至少执行一次）+ `switch` 控制流程：

```cpp
int choice = 0;
do {
    std::cout << "===== CGPA Calculator =====" << std::endl;
    std::cout << "1. 添加课程" << std::endl;
    std::cout << "2. 显示所有课程" << std::endl;
    // ...
    std::cin >> choice;

    switch (choice) {
        case 1: { /* ... */ break; }
        case 2: { /* ... */ break; }
    }
} while (choice != 4);
```

### 关键概念：std::cin 的陷阱

- `std::cin >> x` 读取后在缓冲区留下 `\n`
- 之后的 `std::getline()` 会直接读到残留的 `\n`，表现为"跳过输入"
- **解决方法**：`std::cin >> x` 之后加 `std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');`

### 关键概念：传引用 vs 传值

```cpp
void menu(std::vector<Course>& courses) {  // 有 & = 传引用，修改会影响外部
    courses.push_back(...);                // 正确：修改的是原始数据
}

void menu(std::vector<Course> courses) {   // 无 & = 传值，复制了一份
    courses.push_back(...);                // 错误：修改的是副本，函数返回后丢失
}
```

### 关键概念：Windows 中文乱码

```cpp
#include <windows.h>
int main() {
    SetConsoleOutputCP(65001);  // 设置控制台输出为 UTF-8
    // ...
}
```

如果 clangd 报错，需要先定义 `NOMINMAX`：

```cpp
#define NOMINMAX        // 阻止 windows.h 定义 max/min 宏
#include <windows.h>
```

---

## 第七步：Semester 类（封装一个学期的课程）

### 学到的知识

把数据和操作**绑定在一起**：

```
之前（C 风格）：
main() → vector<Course> + calculateGPA(vector)   ← 数据和函数分离

之后（C++ 风格）：
main() → Semester                                 ← 数据和方法是一体的
├── m_courses (数据)
├── addCourse() (操作)
├── calculateGPA() (操作)
└── printReport() (操作)
```

### 职责分离

| 层 | 做什么 | 在哪里 |
|----|--------|--------|
| 输入 | 从键盘/文件读数据 | `main.cpp` 的 `menu()` |
| 业务逻辑 | 存课程、算 GPA、排序、搜索 | `Semester` 类、`Course` 类 |
| 输出 | 打印菜单、结果显示 | `main.cpp` 的 `menu()` + `Semester::printReport()` |

### Semester 类的实现

```cpp
// semester.h
class Semester {
public:
    Semester(const std::string& name);
    void addCourse(const std::string& name, double credits, const std::string& grade);
    const std::string& getName() const;
    int getCourseCount() const;
    double getTotalCredits() const;
    double getTotalQualityPoints() const;
    double calculateGPA() const;
    void printReport() const;
    void saveToFile(const std::string& filepath) const;
    void loadFromFile(const std::string& filepath);
    void sortByGrade();
    const Course* findCourse(const std::string& name) const;
private:
    std::string m_name;
    std::vector<Course> m_courses;
};
```

---

## 第八步：CGPA（累计绩点）

### 学到的知识

```
GPA  = 当前学期各门课的质量点之和 / 当前学期学分之和
CGPA = 所有学期所有课程的质量点之和 / 所有学期学分之和
```

CGPA **不是**各学期 GPA 之和（绩点最高才 4.0，两个 3.7 不能加起来变 7.4）。

正确计算：
```cpp
double totalQP = 0.0, totalCredits = 0.0;
for (const auto& sem : semesters) {
    totalQP += sem.getTotalQualityPoints();
    totalCredits += sem.getTotalCredits();
}
double cgpa = (totalCredits == 0) ? 0.0 : totalQP / totalCredits;
```

---

## 第九步：文件存储

### 学到的知识

C++ 的文件流和 `cin`/`cout` 语法几乎一样：

| 操作 | 屏幕 | 文件 |
|------|------|------|
| 输出 | `std::cout << x;` | `std::ofstream out("file.txt"); out << x;` |
| 输入 | `std::cin >> x;` | `std::ifstream in("file.txt"); in >> x;` |
| 读一行 | `std::getline(std::cin, s);` | `std::getline(in, s);` |
| 头文件 | `<iostream>` | `<fstream>` |

### 序列化（Serialization）

把对象变成字符串存文件，以及从字符串恢复对象：

```
Course{"Calculus", 4.0, "A"}   →   "Calculus,4.000000,A"   →   存到磁盘
↓
Course{"Calculus", 4.0, "A"}   ←   "Calculus,4.000000,A"   ←   从磁盘读
```

```cpp
// 序列化：对象 → 字符串
std::string Course::serialize() const {
    return m_name + "," + std::to_string(m_credits) + "," + m_grade;
}

// 反序列化：字符串 → 对象
Course Course::deserialize(const std::string& line) {
    size_t pos1 = line.find(',');
    std::string name = line.substr(0, pos1);

    size_t pos2 = line.find(',', pos1 + 1);
    double credits = std::stod(line.substr(pos1 + 1, pos2 - pos1 - 1));

    std::string grade = line.substr(pos2 + 1);
    return Course{name, credits, grade};
}
```

### 用到的字符串操作

| 方法 | 作用 | 示例 |
|------|------|------|
| `s.find(',')` | 找第一个逗号位置 | `"a,b"` → 1 |
| `s.find(',', 3)` | 从位置 3 开始找 | `"a,b,c"` → 3 |
| `s.substr(0, 2)` | 截取 [0, 2) | `"hello"` → `"he"` |
| `s.substr(3)` | 截取 [3, 末尾) | `"hello"` → `"lo"` |
| `std::stod(s)` | 字符串 → double | `"4.0"` → 4.0 |
| `std::to_string(d)` | double → 字符串 | `4.0` → `"4.000000"` |

### 保存学期到文件

文件格式：第一行是学期名称，之后每行一门课（序列化字符串）。

```cpp
void Semester::saveToFile(const std::string& filepath) const {
    std::ofstream out(filepath);
    if (!out) {
        std::cerr << "无法打开文件" << std::endl;
        return;
    }
    out << m_name << std::endl;              // 第一行：学期名称
    for (const auto& course : m_courses) {
        out << course.serialize() << std::endl;  // 每门课一行
    }
    out.close();
}
```

### 从文件加载学期

```cpp
void Semester::loadFromFile(const std::string& filepath) {
    std::ifstream in(filepath);
    if (!in) {
        std::cerr << "无法打开文件" << std::endl;
        return;
    }
    std::getline(in, m_name);          // 第一行：学期名称
    m_courses.clear();
    std::string line;
    while (std::getline(in, line)) {   // 逐行读取
        if (!line.empty()) {
            m_courses.push_back(Course::deserialize(line));
        }
    }
    in.close();
}
```

---

## 第十步：排序与搜索

### 学到的知识

C++ 标准库提供了 `std::sort` 和 `std::find_if`，用 **lambda 表达式** 指定排序/搜索条件。

### 什么是 lambda？

Python：
```python
courses.sort(key=lambda c: c.credits)   # 按学分排序
```

C++：
```cpp
std::sort(courses.begin(), courses.end(),
          [](const Course& a, const Course& b) {       // lambda: 匿名比较函数
          return a.getCredits() < b.getCredits();
          }
          );
```

lambda 语法拆解：

```
[] (const Course& a, const Course& b) { return a < b; }
│  │                                  │  │
│  └─ 参数列表                         │  └─ 函数体
│                                     │
└─ 捕获列表（外部变量想传进来？写 [&name]）
```

### 搜索课程

```cpp
const Course* Semester::findCourse(const std::string& name) const {
    auto it = std::find_if(m_courses.begin(), m_courses.end(),
                           [&name](const Course& c) {               // [&name] 捕获外部变量
                           return c.getName() == name;
                           }
                           );
    if (it != m_courses.end()) {
        return &(*it);                            // 返回指向找到课程的指针
    }
    return nullptr;                               // 没找到
}
```

> `findCourse` 返回指针：找到指向那个 Course，没找到是 `nullptr`。这和 C 里用指针的模式一样，但 C++ 里更常用引用。这里不得不用指针，因为"没找到"这个语义需要 `nullptr`——引用不能为空。

### 排序

```cpp
void Semester::sortByGrade() {
    std::sort(m_courses.begin(), m_courses.end(),
              [](const Course& a, const Course& b) {
              return a.getGrade() < b.getGrade();
              }
              );
}
```

> `std::sort` 修改 vector 的元素顺序，所以 `sortByGrade` 不能声明为 `const`。

---

## 编译与运行

```powershell
g++ -std=c++17 src/main.cpp src/course.cpp src/semester.cpp -I include -o main.exe
.\main.exe
```

---

## 常见错误排查

| 错误信息 | 原因 | 解决 |
|----------|------|------|
| `undefined reference to 'XXX'` | 头文件声明了但 .cpp 没实现 | 在 .cpp 补充实现 |
| `extra qualification 'Course::' on member` | .h 文件里多写了 `Course::` | .h 里不写 `Course::` |
| `Expected 'while' in do/while loop` | `while` 写在 do 块里面了 | `while` 要在 `}` 之后 |
| `No member named 'push_back' in 'Semester'` | 对 Semester 调了 vector 的方法 | 用 `semester.addCourse(...)` |
| `'m_courses' is a private member` | 外部访问了类的 private 成员 | 通过 public 方法访问 |
| 中文乱码 | Windows 控制台默认 GBK | 加 `SetConsoleOutputCP(65001)` |

### Windows 特别提示

`windows.h` 会定义 `max` / `min` 宏，与 `std::numeric_limits::max()` 冲突。解决方法：

```cpp
#define NOMINMAX        // ← 必须在 #include <windows.h> 之前
#include <windows.h>
```

---

## 完整的知识点图谱

```
CGPA 计算器
│
┌──────────────────┼──────────────────┐
│                  │                  │
数据层 (Course)     逻辑层 (Semester)    交互层 (main)
│                  │                  │
┌────┴────┐       ┌─────┴─────┐      ┌────┴────┐
│ class   │       │  vector   │      │ do-while│
│ private │       │  GPA 公式  │      │ switch  │
│ getter  │       │  文件 I/O  │      │  cin    │
│ const   │       │  sort     │      │ getline │
│ map     │       │  find_if  │      │ 引用    │
└─────────┘       └───────────┘      └─────────┘
│                  │                  │
└──────────────────┼──────────────────┘
│
多文件编译 (.h/.cpp)
编译链接模型
```

---

## 可扩展方向

完成基本功能后，可以继续添加：

1. **删除/修改课程** — 练习 vector 的 `erase` 操作
2. **更丰富的排序选项** — 按学分、按绩点、按名称排序
3. **成绩分布统计** — 计算平均分、最高分、最低分
4. **更健壮的输入验证** — 检查学分 > 0、成绩必须是合法的 A-F
5. **CMake 构建系统** — 替代手写 g++ 命令
