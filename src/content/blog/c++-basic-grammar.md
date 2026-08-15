---
title: "c++ 基础语法"
description: "以学C后快速了解C++ 基础语法"
date: 2026-08-15
tags: [c++]
type: note
topic: "C++"
---

> **本文定位**：假设你已会 C（变量、指针、结构体、控制流都学过），下面只讲 C++ 新增 / 不同的东西。每节带两块上下文：**C→C++ 对比**（C 里怎么写的、为什么 C++ 这么设计）和 **实战标注**（这个知识点我在哪个项目里用过）。

## 1. 输入与输出

```cpp
#include <iostream> // 包含输入输出流库

int main() {
    std::cout << "Hello, World!" << std::endl; // 输出
    int a;
    std::cin >> a; // 输入
    return 0;
}
```

> **C→C++ 对比**：
> - C 用 `printf`/`scanf`，要手动写格式符 `%d`、`%f`，类型写错输出就乱；C++ 用 `<<`/`>>` 自动推断类型，不需要格式符。
> - `std::endl` = 换行 + 刷新缓冲区，比 `'\n'` 多一次刷新；只想换行用 `'\n'` 更快。
> - `cout`/`cin` 是流对象，靠 `operator<<`/`operator>>` 重载工作——这也是后面"运算符重载"的基础。

## 2. 变量与数据类型

```cpp
#include <iostream>
#include <string>
#include <vector>

std::string name = "Alice"; // 字符串
// relative method
name.length(); // 获取长度
name.substr(0, 3); // 截取子串
name.find("A"); // 查找子串位置
name.replace(0, 1, "B"); // 替换子串

std::vector<int> numbers = {1, 2, 3}; // 动态数组
numbers.push_back(4); // 添加元素
numbers.emplace_back(5); // 原地构造添加元素
numbers.size(); // 获取大小
numbers.clear(); // 清空数组
numbers.empty(); // 判断是否为空
```

> **C→C++ 对比**：
> - `std::string` 对应 C 的 `char*`/`char[]`。C 里要手动 `strlen`/`strcpy`/`strcat`/`strcmp`，C++ 直接用成员方法 `.length()`、`+` 拼接、`==` 比较，还自动管理内存，不用手动 `free`。
> - `std::vector` 对应 C 的定长数组。C 里要 `malloc` + 自己记录长度 + `realloc` 扩容；`vector` 自动扩容，`.size()` 直接给长度。
> - `std::string name = "Alice";` 写在函数外是**全局变量**，而且 `name.length();` 这类语句必须在函数体（如 `main`）里执行——上面这段是示意，别原样放全局作用域。


## 3. 控制流

```cpp
if else // in c have learnd
switch {case}
for while do while // loop
for (auto& item : container) // range-based for loop
for (auto it = container.begin(); it != container.end(); ++it) // iterator-based for loop
```

> **C→C++ 对比**：
> - `if`/`for`/`while`/`switch` 的语法和 C 几乎一样，只是 C++ 有专门的 `bool` 类型（C 里常拿 `int` 的 0/1 冒充）。
> - **范围 for** 是 C++11 新增，C 里没有。C 遍历数组要写 `for (int i = 0; i < n; i++)`；C++ 直接 `for (auto& x : vec)`，`auto` 自动推导类型，`&` 是引用（见第 7 节）。
> - **迭代器**可以理解为"C 里指针的泛化"：`begin()` ≈ 首地址，`end()` ≈ 尾后地址，`*it` ≈ `*p`，`++it` ≈ `p++`。范围 for 内部就是迭代器语法糖。


## 4. struct 与 class

```cpp
struct Point {
    int x;
    int y;
    Point(int x, int y) : x(x), y(y) {} // 构造函数
    void print() {
        std::cout << "Point(" << x << ", " << y << ")" << std::endl;
    }
};

class Circle {
public:
    int getRadius() const { return radius; } // 获取半径
    Circle(int r) : radius(r) {} // 构造函数
    void Area() const {
        std::cout << "Area: " << 3.14 * radius * radius << std::endl;
    }

private:
    int radius;
}
```

struct 与 class 的区别：

- struct 默认成员是 public，class 默认成员是 private
- struct 主要用于数据结构，class 主要用于封装行为和数据
- 继承时，struct 默认 public 继承，class 默认 private 继承。这也是语言区别之一

> **C→C++ 对比**：
> - C 的 `struct` 只能放数据，而且要用 `typedef struct Point {...} Point;` 才能省略 `struct` 关键字；C++ 里 struct 可以有成员函数，定义完直接写 `Point`，不需要 `typedef`。
> - `class` 是 C 里完全没有的东西。`private` 成员外部不可访问，只能通过 `public` 成员函数操作——这就是**封装**。
> - **构造函数初始化列表** `Circle(int r) : radius(r)`：C 里没有构造函数，只能靠写个 `init()` 手动初始化。
> - `int getRadius() const`：末尾的 `const` 表示"这个函数不改动对象成员"，C 里没有对应概念（详见第 11 节）。
> - 注意：`class Circle {...}` 结尾必须有分号 `;`，上面 `Circle` 的 `}` 后漏了 `;`，补上才能编译。struct 同理。


## 5. 继承与多态

```cpp
class Shape {
public:
    virtual void draw() const = 0; // 纯虚函数，抽象类
    virtual ~Shape() = default; // 虚析构函数，确保派生类对象被正确销毁
};

class Circle : public Shape {
public:
    void draw() const override { // 重写虚函数
        std::cout << "Drawing Circle" << std::endl;
    }
};

class Square : public Shape {
public:
    void draw() const override {
        std::cout << "Drawing Square" << std::endl;
    }
};
```

> **C→C++ 对比**：
> - 多态是 C++ 相对 C 的大新增。C 想模拟"同一接口、不同行为"只能写函数指针数组或 if-else 分支；C++ 用 `virtual` 虚函数 + 指针/引用 + 虚表（vtable），在运行时自动选对 `draw()`。
> - `= 0` 的纯虚函数让 `Shape` 变成**抽象类**，不能直接实例化，只能由 `Circle`/`Square` 这种派生类使用——这是"接口"的雏形。
> - `virtual ~Shape() = default;` 是**虚析构函数**：通过基类指针 `delete` 派生类对象时，保证先调派生类析构再调基类析构，避免资源泄漏。


## 6. 模板与泛型编程

```cpp
template <typename T>
class Stack {
    std::vector<T> data;
public:
    void push(const T& value) { data.push_back(value); }
    void pop() { if (!data.empty()) data.pop_back(); }
    T& top() { return data.back(); }
    bool empty() const { return data.empty(); }
};
```

> **C→C++ 对比**：
> - C 没有模板。想写通用容器只能用 `void*`（丢类型、不安全）或 `#define` 宏（没类型检查）；C++ 模板在**编译期**按传入类型生成代码，类型安全、运行期零开销。
> - `typename T` 就是"类型参数"，`Stack<int>` 和 `Stack<std::string>` 会被编译成两份独立代码。


## 7. 引用与指针

```cpp
int a = 10;
int& ref = a;  // 引用：ref 是 a 的别名，改 ref 就是改 a
ref = 20;      // a 变成 20
int* ptr = &a; // 指针：存 a 的地址，取值要 *ptr
```

> **C→C++ 对比**：
> - C 里只有指针；C++ 新增**引用**。引用本质是"隐式指针"，但**不能为空、不能重新绑定**，用起来像普通变量，不需要 `*`/`&` 符号。
> - 经验法则：**能用引用就不用指针**。函数传参、遍历容器用引用避免拷贝；只有在"可能为空"或"需要改绑"时才用指针（如链表节点）。


## 8. 智能指针（unique_ptr）

```cpp
#include <memory>

std::unique_ptr<int> p = std::make_unique<int>(42); // 代替 new
*p = 100;         // 用法和普通指针一样
// 离开作用域自动释放，不需要手动 delete
```

> **C→C++ 对比**：
> - C 用 `malloc`/`free`，C++ 用 `new`/`delete`，但"谁负责释放"很难管，容易内存泄漏或重复释放。
> - `unique_ptr` 是**独占所有权**的智能指针：同一对象同一时刻只有一个 owner，生命周期结束自动释放，从根上消除泄漏。
> - `make_unique<T>(构造参数)` 是推荐创建方式，比直接 `new` 更安全（异常时也不会漏）。


## 9. STL 常用容器（map / set）

```cpp
#include <map>
#include <set>

std::map<std::string, int> scores; // 键值对，按键自动排序
scores["Alice"] = 90;              // 插入 / 修改（键不存在会自动插入）
scores.count("Alice");             // 键是否存在：1 存在 / 0 不存在
for (auto& [k, v] : scores) { ... } // 遍历：结构化绑定取出键和值

std::set<int> ids;                 // 有序集合，自动去重
ids.insert(3);
ids.insert(3);                     // 重复插入无效
```

> **C→C++ 对比**：
> - C 没有内置字典 / 集合，要么自己实现哈希表或红黑树，要么找第三方库。
> - `map` 内部是红黑树（有序，`O(log n)`）；`unordered_map` 是哈希表（无序但常数级）。数据结构课上的知识在这里直接落地。
> - 用 `[]` 时**不存在的键会自动插入默认值**；只想查询不插入用 `.find()`/`.count()`。


## 10. lambda 表达式

```cpp
#include <algorithm>

std::vector<int> v = {3, 1, 2};
std::sort(v.begin(), v.end(), [](int a, int b) { return a < b; }); // 升序
auto it = std::find_if(v.begin(), v.end(), [](int x) { return x > 2; }); // 找第一个 >2 的
```

> **C→C++ 对比**：
> - lambda 是"内联的匿名函数"，C 里没有；C 想传行为只能写具名函数 + 函数指针。
> - `[](参数){ 函数体 }`：`[]` 是捕获列表，空表示不捕获外部变量；需要外部变量时写 `[=]`（按值捕获）或 `[&]`（按引用捕获）。
> - 通常配合 `<algorithm>` 的 `sort`/`find_if`/`count_if` 用，比手写循环更能表达意图。


## 11. const 修饰符小结

```cpp
const int a = 5;               // 常量，不能修改
int getX() const;              // const 成员函数：保证不改对象成员（只读）
void f(const std::string& s);  // const 引用传参：只读 + 避免拷贝
void f(const int* p); // const 指针：指针指向的内容不可改
```

> **C→C++ 对比**：
> - C 里 `const` 基本只是"只读变量"；C++ 里 **const 成员函数**和 **const 引用传参**是日常高频用法。
> - const 成员函数（末尾加 `const`）：告诉编译器"这个函数不会改对象"，这样 const 对象也能调用它。
> - const 引用传参：既避免拷贝大对象，又防止意外修改。**读参数一律写 `const T&`**。
