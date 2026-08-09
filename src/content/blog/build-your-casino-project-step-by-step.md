---
title: "C++ 学习笔记 — 赌场数字猜测游戏"
date: 2026-07-26
tags: [c++, project]
---

# C++ 学习笔记 — 赌场数字猜测游戏

> 记录日期：2026-07-26
> 学习方式：从零构建一个 C++ 项目，逐步引入新概念
> 前置知识：C / Python / JavaScript / CSAPP / 数据结构

---

## 目录

1. [项目演变：四个阶段](#1-项目演变四个阶段)
2. [数据类型进化](#2-数据类型进化)
3. [内存管理进化](#3-内存管理进化)
4. [踩过的坑（正误对比）](#4-踩过的坑正误对比)
5. [现代 C++ 特性总览](#5-现代-c-特性总览)
6. [多态架构（项目核心）](#6-多态架构项目核心)
7. [工程能力](#7-工程能力)
8. [已学 vs 未学](#8-已学-vs-未学)

---

## 1. 项目演变：四个阶段

代码经历了 4 次重构，每个阶段引入一批新概念：

```
阶段1: 单文件 main()           ← C 风格，只有循环/条件
阶段2: struct + 函数           ← 引入引用 &、do-while
阶段3: class + 多文件           ← 引入封装、头文件/源文件分离
阶段4: 抽象基类 + 多态          ← 引入继承、虚函数、智能指针
```

### 阶段 1：单文件

```cpp
int number = rand() % 10 + 1;   // 问题：没播种，每次运行同一个"随机数"
// 修正：srand(time(nullptr)) 放 main() 里，只调用一次
```

**教训：** `rand()` 是伪随机，必须播种。`srand()` 应该只调用一次。

### 阶段 2：struct + 函数

```cpp
struct GameState {
    int secretNumber = 0;
    int attempts = 0;
};

void playGuessingGame(GameState& state) { ... }  // 引用 &，不能为空
```

**新概念：** 引用 `&` —— 指针的语法糖，不能为 null、不需要解引用。

### 阶段 3：class + 多文件

```cpp
// player.h —— 声明
class Player {
public:
    Player(std::string name, double initialBalance);
    void addResult(const GameResult& result);
    void displayStats() const;
private:
    std::string name;
    double balance;
    std::vector<GameResult> history;
};

// player.cpp —— 定义
Player::Player(std::string name, double initialBalance)
    : name(name), balance(initialBalance) {}
```

**新概念：**
- 类 + 封装（`public` / `private`）
- 构造函数 + 初始化列表
- `const` 成员函数（承诺不修改成员）
- `std::vector`（自动扩容的动态数组）
- 多文件项目组织（`.h` 声明 / `.cpp` 实现 / `::` 作用域解析）

### 阶段 4：抽象基类 + 多态

```cpp
class CasinoGame {                      // 抽象基类
public:
    virtual void displayRules() const = 0;  // 纯虚函数
    virtual GameResult play(Player& player) = 0;
    virtual ~CasinoGame() = default;        // 虚析构
};

class NumberGuessingGame : public CasinoGame {
public:
    void displayRules() const override;
    GameResult play(Player& player) override;
};
```

**新概念：** 继承、`virtual`、纯虚函数 `= 0`、`override`、虚析构函数。

---

## 2. 数据类型进化

```
C 语言:  struct GameState { int secret; int attempts; };
          只能存数据，方法在外面

阶段2:   struct GameState { ... };  +  独立函数 playGuessingGame()
          数据和方法分离

阶段3:   struct GameResult { ... };  +  构造函数 + operator<<
          struct 开始"有行为"了

阶段4:   class Player {
              private: std::vector<GameResult> history;
              public:  void addResult(...);
          };
          数据隐藏（private）+ 行为封装在类里
```

**核心认知转变：** 数据从"被动存放"变成"主动管理自己"。这就是 OOP 的第一步。

---

## 3. 内存管理进化

```
C:       malloc() → 用 → free()          ← 忘了 free = 内存泄漏
阶段3:   std::vector<GameResult>          ← 自动扩容、自动释放
阶段4:   std::unique_ptr<CasinoGame>      ← 离开作用域自动 delete
```

**为什么 C++ 更安全？** 核心机制叫 **RAII**（Resource Acquisition Is Initialization）：

- 资源在构造时获取，在析构时自动释放
- 对象离开作用域时，编译器自动调用析构函数
- `vector` 和 `unique_ptr` 底层就是 `new`/`delete`，但释放**不可能被忘记**

对比 CSAPP 学过的 C 内存 bug：悬垂指针、double-free、内存泄漏——C++ 用 RAII 从语言层面消除了这些。

### unique_ptr 细节

```cpp
unique_ptr<CasinoGame> a = make_unique<NumberGuessingGame>();
unique_ptr<CasinoGame> b = a;   // 错误：编译错误！不能复制
unique_ptr<CasinoGame> b = std::move(a);  // 正确：转移所有权，a 变空
```

- **独占所有权**：任何时候只有一个人"拥有"对象
- 离开作用域自动 delete，即使中间有 `return` 或异常也保证释放

---

## 4. 踩过的坑（正误对比）

| # | 错误 | 正确 | 学到的概念 |
|---|------|------|-----------|
| 1 | `srand()` 放在函数里 | 放 `main()`，只调用一次 | 同一秒播种 → 相同"随机"数 |
| 2 | `.cpp` 里重复定义 struct | 头文件定义一次，.cpp 只 include | 声明 vs 定义 |
| 3 | 漏写 `public:` | 继承类的成员默认 private | 访问控制符 |
| 4 | 头文件没有 `#pragma once` | 加 `#pragma once` | header guard |
| 5 | 普通函数体写在 `.h` 里 | 加 `inline` 或移去 `.cpp` | 多文件包含 → multiple definition |
| 6 | clangd 报 `.h` file not found | `compile_flags.txt` 加 `-Iinclude` | 头文件搜索路径 |
| 7 | `uniform_int_distribution dist(gen)` | `dist(1, 100)` + 调用时 `dist(gen)` | 分布构造参数是范围 |
| 8 | `play()` 里调用 `addResult()` | 只返回 `GameResult`，main 负责结算 | 职责分离 |

---

## 5. 现代 C++ 特性总览

| C++ 特性 | 一句话 | 类比 |
|----------|--------|------|
| `enum class` | 强类型枚举，不能隐式转 int | 比 C enum 安全 |
| `inline` | 允许函数体在 `.h` 里 | 类似 C 宏但安全 |
| `operator<<` | 自定义类型的输出 | Python `__str__` |
| `std::string` | 自动管理内存的字符串 | JS string，但可变 |
| `std::vector` | 动态数组 | Python list |
| 引用 `&` | 不能为空的指针 | 比 C 指针安全 |
| `const` 成员函数 | 承诺不改数据 | 编译期检查 |
| 纯虚函数 `= 0` | 强制子类实现 | Python `@abstractmethod` |
| `override` | 显式标记重写 | 防写错签名 |
| `unique_ptr` | 独占所有权智能指针 | Python 自动 GC，但零开销 |
| `make_unique` | 安全的 `new` | — |
| `<random>` (mt19937) | 高质量随机数 | 比 `rand()` 更均匀 |
| `::` 作用域解析 | `Player::addResult()` | 类似 Python `Class.method` |

### 运算符重载（`operator<<`）详解

**核心认知：运算符只是长得特殊的函数名。**

```cpp
// 你看到的：                      // 编译器翻译成：
a + b                →           operator+(a, b)
a == b               →           operator==(a, b)
cout << result       →           operator<<(cout, result)
```

重载运算符 = 写一个名字是 `operator+` / `operator<<` 的特殊函数。

#### 项目里的真实例子

```cpp
std::ostream& operator<<(std::ostream& os, const GameResult& r) {
    os << "Secret: " << r.secretNumber << "\n";
    return os;
}
```

**① 参数从哪来？**

```cpp
cout << result;
//   ↑        ↑
// 第一个参数   第二个参数
// (os)       (r)
```

`<<` 是二元运算符，两个操作数 `cout` 和 `result` 映射成两个参数。**左操作数是第一个参数，右操作数是第二个参数。**

**② 为什么返回 `ostream&`？**

```cpp
cout << r1 << r2;
// 展开成: operator<<(operator<<(cout, r1), r2);
//                   ↑ 内层必须返回 cout，外层才能继续
```

所以 `return os;` 是"把流传回去，让下一个 `<<` 还能继续"。

#### 为什么要重载？

**不重载**：每次输出一条记录要写 7 行 cout。
**重载后**：`cout << r;` 一行搞定。

| 语言 | 机制 |
|------|------|
| Python | `def __str__(self):` — `print(obj)` 调用它 |
| JS | `obj.toString()` |
| C++ | `operator<<` — `cout << obj` 调用它 |

本质一样：**让自定义类型"懂得如何被输出"。** 区别是 C++ 能改写运算符语法本身。

#### 以后会遇到的其他重载

```cpp
// 让 std::sort 能排自定义类型：
bool operator<(const Player& a, const Player& b) {
    return a.getBalance() < b.getBalance();
}

// 让 std::find 能找到目标记录：
bool operator==(const GameResult& a, const GameResult& b) {
    return a.roundNumber == b.roundNumber && a.won == b.won;
}
```

**威力所在：** STL 算法（sort、find、count）是泛型写好的，只要你的类型"支持"某种运算符，算法就能直接用。运算符就是类型对外暴露的接口。

---

## 6. 多态架构（项目核心）

```
CasinoGame (抽象基类)
    ├── play() 纯虚函数      —— "所有游戏都要有 play，但我不管你怎么玩"
    ├── displayRules() 纯虚函数
    └── ~CasinoGame() 虚析构  —— "通过父类指针删除子类对象时也要正确销毁"
        │
        ├── NumberGuessingGame : public CasinoGame
        │       └── play() —— 猜数字逻辑
        │
        └── SlotMachine : public CasinoGame
                └── play() —— 老虎机逻辑

main.cpp:
    std::unique_ptr<CasinoGame> game;          // 父类指针
    game = std::make_unique<SlotMachine>();    // 运行时决定
    game->play(player, diff);                  // 自动找对子类 → 多态
```

### 多态底层原理（联系 CSAPP）

每个有虚函数的类，编译器自动加一个隐藏成员 —— 虚函数表指针（vptr）：

```
NumberGuessingGame 对象:
┌──────────────────┐
│ [vptr] ──────→ 虚函数表:
│                  │  [0] → &NumberGuessingGame::displayRules()
│                  │  [1] → &NumberGuessingGame::play()
└──────────────────┘  [2] → &NumberGuessingGame::~NumberGuessingGame()

调用 game->play() 底层就是:
    game->vptr[1](game);    ← 查表跳转，等价 C 的函数指针表
```

**核心价值：面向接口编程，而不是面向实现编程。** 加第三个游戏，main.cpp 一行不用改。

### 虚析构函数详解

#### 问题：没有虚析构会怎样？

```cpp
class SlotMachine : public CasinoGame {
    int* wheels;                      // 堆内存资源
public:
    SlotMachine() { wheels = new int[3]; }
    ~SlotMachine() { delete[] wheels; }   // 释放堆内存
};

// 可能这样用：
CasinoGame* game = new SlotMachine();   // 基类指针，指向子类对象
delete game;                            // ← 危险！
```

```
没有 virtual 时：
    delete game;
      ↓ 编译器只看 game 的类型是 CasinoGame*
      ↓ 静态绑定 → 只调 ~CasinoGame()
      ↓ 但基类没有 wheels → wheels 永远不释放 → 内存泄漏

有 virtual 时：
    delete game;
      ↓ 虚函数机制 → 查虚函数表 → 找到真身 SlotMachine
      ↓ 先调 ~SlotMachine()（释放 wheels）
      ↓ 再自动调 ~CasinoGame()（基类部分）
      ↓ 完整清理，零泄漏
```

#### C 语言类比

```c
// C 里两个"清理函数"，调错了就泄漏：
void cleanup_slot_machine(struct game* g) { free(g->wheels); }  // 正确
void cleanup_generic(struct game* g)       { /* 什么都不做 */ }  // 泄漏

struct game* g = create_slot_machine();
cleanup_generic(g);  // 调错清理函数 → wheels 泄漏
```

**C++ 虚析构 = 编译器自动帮你选对"清理函数"。** 写 `delete game`，自动查表选子类的清理逻辑。

#### 为什么现在的代码没出问题？

因为 `SlotMachine` 目前**没有堆内存成员**——数据都在对象内部。即使析构没被正确调用也不会泄漏。

但这是**隐患**：以后往子类加任何动态资源（`new`、`vector`、`unique_ptr`、`fstream`），没有虚析构就会悄悄泄漏。

**规则：任何有虚函数的类，必须写虚析构函数 `virtual ~CasinoGame() = default`。**
这是为**未来的子类**准备的，不是现在的。

#### 对比 GC 语言

```
Python/JS: 引用计数/GC 自动回收，从不手动 delete，不需要析构。
C++:       没有 GC。delete 是你自己写的，必须确保它调用"最深层"的清理逻辑。
           virtual 析构 = 保证这一点。
```

#### 记忆图

```
没有虚析构:  delete game → 只清基类部分 ← 子类资源泄漏
有虚析构:    delete game → 先清子类 → 再清基类 → 干净
```

---

## 7. 工程能力

- **多文件组织**：`.h` 放声明、`.cpp` 放实现
- **clangd 配置**：`compile_flags.txt`（`-Iinclude -xc++ -std=c++17`）
- **CMake**：`CMakeLists.txt` 描述构建 → `cmake -B build -G "MinGW Makefiles"` → `cmake --build build`
- **职责分离**：`play()` 返回结果，`main()` 负责结算——单一职责

### CMake 与 g++ 对应关系

```
g++ src/*.cpp -Iinclude -std=c++17 -o build/game.exe
│    │        │         │           │
│    └─ GLOB ┘         │           └─ add_executable(game ...)
│                      └─ set(CMAKE_CXX_STANDARD 17)
└─ include_directories(include)
```

### CMake vs Makefile

```
CMake       → 项目描述（跨平台，你写 CMakeLists.txt）
  ↓ 生成
Makefile    → 构建指令（CMake 自动生成，不用你写）
  ↓ 执行
make        → 实际调用 g++ 编译
```

---

## 8. 已学 vs 未学

### 已学

面向对象：封装、继承、多态、抽象基类、虚函数、纯虚函数、虚析构、override
STL：vector、count_if、accumulate、max_element、lambda
内存：unique_ptr、make_unique、RAII
现代 C++：enum class、auto、inline、operator<<、引用、const、<random>
文件 I/O：ofstream、ifstream
序列化：nlohmann/json（toJson/fromJson）
工程：多文件、CMake、clangd 配置、返回 bool 报告成败

### 未学（候选）

```
STL 容器:      std::map（类比 Python dict）
STL 算法:      sort / find_if / transform / remove_if
模板 template  泛型编程
异常 try/catch
```

---

## 9. Plan B：文件 I/O + STL 算法（2026-08-09 完成）

### 9.1 文件 I/O（对比 C）

```
C:       FILE* f = fopen("a.txt", "w");  fprintf(...);  fclose(f);
C++:     ofstream f("a.txt");            f << ...;      // 离开作用域自动关
         ifstream f("a.txt");            f >> ...;      // 像 cin 一样读
```

- `ofstream` 像 `cout`（`<<` 输出），`ifstream` 像 `cin`（`>>` 输入）
- RAII：文件流离开作用域自动 close，不会忘关
- **检查打开失败**：`if (!file) { ... }` — 这是必须的健壮性检查

### 9.2 nlohmann/json 序列化

```cpp
json j;
j["name"] = "Alice";              // 像 Python dict
j["balance"] = 520.0;
j["history"].push_back(item);     // 数组

// 读回：
std::string n = j["name"];
j.at("key")     // 安全读取：key 不存在抛异常（推荐）
j["key"]        // 危险：key 不存在会自动创建空值
```

**自定义类型序列化的两种机制：**

```
机制 A（本项目采用）：成员函数
    json GameResult::toJson() const;
    static GameResult GameResult::fromJson(const json& j);
    // 手动调用: j["history"].push_back(r.toJson());

机制 B（ADL 查找）：free 函数
    void to_json(json& j, const GameResult& r) { ... }
    void from_json(const json& j, GameResult& r) { ... }
    // nlohmann 自动调用: j["history"] = history;
```

**坑：`j["history"] = history;` 编译失败** — 因为 GameResult 用的是机制 A（成员函数），nlohmann 只认识机制 B（ADL free 函数）。选 A 就手动遍历，选 B 才能直接赋值。

### 9.3 STL 算法 + lambda

```cpp
#include <algorithm>  // count_if, max_element
#include <numeric>    // accumulate

// 数满足条件的元素：count_if(begin, end, 条件)
int wins = std::count_if(history.begin(), history.end(),
                         [](const GameResult& r) { return r.won; });

// 累加所有元素：accumulate(begin, end, 初始值, 操作)
double profit = std::accumulate(history.begin(), history.end(), 0.0,
                                [](double sum, const GameResult& r) {
                                    return sum + (r.won ? r.prize : -r.entryFee);
                                });

// 找最大元素：max_element(begin, end, 比较) → 返回迭代器
double maxPrize = std::max_element(history.begin(), history.end(),
                                   [](const GameResult& a, const GameResult& b) {
                                       return a.prize < b.prize;
                                   })->prize;   // 迭代器用 -> 访问成员
```

**lambda 表达式：** `[](参数列表) { 函数体 }`
- 等价于一个匿名函数，内联在调用处
- Python: `lambda r: r.won`
- 注意 `max_element` 返回的是**迭代器**，用 `->` 取成员（不是 `.`）

### 9.4 本次踩过的坑

| 坑 | 根因 | 修复 |
|----|------|------|
| `#include <json.hpp>` 报错 | 尖括号只搜系统目录 | 项目文件用 `#include "json.hpp"` |
| `Game Result&` 编译错误 | 类名拼错，多了空格 | `GameResult&` |
| `int maxPrize` 丢小数 | prize 是 double | 金额一律用 double |
| `j["history"] = history` 失败 | 机制 A vs 机制 B | 手动遍历 + toJson() |
| 读档后显示"玩家1" | if/else 只写了 if 分支，漏了 else 从存档加载 | 补上加载分支 |
| 存档被覆盖成默认玩家 | 读档失败时退出存档覆盖好数据 | 设计漏洞，见下 |

### 9.5 设计教训

1. **函数应该返回 `bool` 报告成败** — `loadFromFile` 返回 `true/false`，调用者才能决定流程。不返回成功与否，调用者只能用"余额>0"这种间接判断，容易误判。

2. **if/else 对称性** — 写了 `if (!hasLoaded) { 新玩家 }` 却漏了 `else { 用存档 }`。写完 if/else 要检查：**两个分支都处理了吗？**

3. **覆盖式存档的危险** — 读档失败时退出存档会覆盖原好数据。真实项目应该：读档失败不覆盖、或确认覆盖、或分批文件。

---

## 后续 TODO

- [ ] 读档失败时不覆盖好存档（9.5 提到的设计漏洞）
- [ ] 加第三个游戏（如轮盘 Roulette）验证多态扩展
- [ ] `std::map` 按难度统计胜率
- [ ] 模板 / 异常 / 更多 STL 算法
