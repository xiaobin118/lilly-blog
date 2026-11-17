---
title: "文本 ↔ 数字：std::stoi / std::to_string"
description: "解析外部输入时的类型转换与异常处理"
date: 2026-08-15
tags: [cpp, string, conversion]
type: note
topic: "C++"
---


# 文本 ↔ 数字：std::stoi / std::to_string

## Concept

C++ 里文本和数字之间的转换有两个方向，标准库各给了一组函数：

- **文本 → 数字**：`std::stoi` / `std::stol` / `std::stoll` / `std::stoul` / `std::stod` /
  `std::stof`，从 `std::string` 解析，失败**抛异常**
- **数字 → 文本**：`std::to_string`，重载覆盖所有整数和浮点类型

这组 API 的设计取向是"解析成功就返回，解析失败就抛"——没有返回码，也没有输出参数。
好处是调用点干净，坏处是**外部输入不可信时，异常处理变成了强制项**：`std::stoi` 碰到
空串、非数字、超范围，一律抛异常，不 catch 就是 `std::terminate`。

三个容易忽略的语义细节：

1. `stoi` 会**跳过前导空白**（`isspace`），然后解析可选正负号 + 数字
2. 不传 `pos` 参数时，它**不检查尾部垃圾**——`stoi("123abc")` 返回 `123`，不报错
3. 默认十进制；`stoi("0x10")` 返回 `0` 且不抛异常（解析到 `'x'` 停下），要解析十六进制
   必须显式传 `base = 16` 或 `base = 0`

## Example

先看反序列化方向。假设一条记录是 `|` 分隔的定界文本，切分后第 4、5 个字段是成绩：

```cpp
// 反序列化：文本 → int（成绩）
rec.scoreChinese = std::stoi(parts[4]);
rec.scoreMath    = std::stoi(parts[5]);

// 序列化：int → 文本（成绩）
out += std::to_string(scoreChinese);
```

数据库那边也一样——`PQgetvalue` 返回的是 `const char*`，本质上还是文本：

```cpp
// libpq：数据库返回的也是文本，同样要转
rec.scoreChinese = std::stoi(PQgetvalue(res, i, 4));
```

### 为什么必须 try-catch

```cpp
try {
    scoreChinese = std::stoi(parts[4]);
} catch (const std::exception&) {
    return false;   // 空串/非数字/超范围都算"坏行"，整行丢弃
}
```

`std::stoi` 对空字符串抛 `invalid_argument`、对超 int 范围抛 `out_of_range`，**不 catch 程序直接崩**。
而"某行成绩是文本"是可预期的（有人手改过文件），不是程序 bug，所以用返回值让上层跳过坏行。

两个异常类型都继承自 `std::logic_error`，进而继承自 `std::exception`，所以一个
`catch (const std::exception&)` 能覆盖两种情况。想把"格式错"和"数值越界"分开处理时，
分别 catch `std::invalid_argument` 和 `std::out_of_range` 即可。

### 封装成安全解析函数

逐个字段写 `try/catch` 太啰嗦，抽成小函数，把"失败"编码进返回值：

```cpp
#include <optional>
#include <string>

std::optional<int> to_int(const std::string& s) {
    try {
        size_t pos = 0;
        int v = std::stoi(s, &pos);
        if (pos != s.size()) return std::nullopt;  // 尾部有垃圾，拒绝
        return v;
    } catch (const std::exception&) {
        return std::nullopt;
    }
}
```

`pos` 输出参数是"被消耗的字符数"（包含前导空白）。传了它就能做**严格解析**：
`to_int("42 ")` 里 `pos == 2 != 3`，返回 `nullopt`——尾部空白也算垃圾。要宽松一点就
在比较前先 `trim` 掉尾部空白，或者干脆不检查 `pos`。

调用侧变成一行，坏行自然被跳过：

```cpp
auto score = to_int(parts[4]);
if (!score) continue;          // 坏行，跳过
rec.scoreChinese = *score;
```

## 边界行为

`std::stoi` 在不同输入下的表现（默认 `base = 10`）：

| 输入 | 返回值 | 异常 | 说明 |
| --- | --- | --- | --- |
| `"42"` | 42 | — | 正常 |
| `" 42"` | 42 | — | 跳过前导空白 |
| `"+42"` | 42 | — | 接受正号 |
| `"-42"` | -42 | — | 接受负号 |
| `"42abc"` | 42 | — | 尾部垃圾**不报错**（不传 `pos` 时） |
| `"abc"` | — | `invalid_argument` | 没有可转换字符 |
| `""` | — | `invalid_argument` | 空串 |
| `"-"` | — | `invalid_argument` | 只有符号 |
| `"99999999999"` | — | `out_of_range` | 超 `int` 范围 |
| `"0x10"` | 0 | — | 默认十进制，解析到 `'x'` 停 |
| `"0x10"` + `base=0` | 16 | — | `0x` 前缀被识别 |
| `"010"` + `base=0` | 8 | — | 前导 `0` 按八进制！ |

最后一行是经典陷阱：`base = 0` 时按 C 字面量规则推断进制，`"010"` 是八进制 8，不是十进制 10。
解析用户输入的十进制数时，**永远显式写 `base = 10`**，别偷懒用 `0`。

## 序列化方向：to_string

`std::to_string` 对整数没有坑，`to_string(-5)` 得到 `"-5"`。浮点就麻烦了：

```cpp
std::to_string(3.14159265358979);   // "3.141593"  只保留 6 位小数
std::to_string(1e-10);              // "0.000000"  直接归零
std::to_string(1e300);              // 一长串数字，不是科学计数法
```

它内部走的是 `sprintf("%f")`，**固定 6 位小数**。这意味着：

- 精度不够，`double` 往返转换后不相等
- 极大/极小值输出畸形
- 受当前 C locale 影响，某些 locale 下小数点是 `,` 而不是 `.`

只要涉及浮点的持久化或网络传输，就别用 `to_string`。C++17 的 `std::to_chars` 才是正解
（见下节），或者用 `std::format`（C++20）：

```cpp
std::string s = std::format("{}", 3.14159265358979);  // "3.14159265358979"
```

## 进阶：from_chars / to_chars

C++17 给了 `<charconv>` 里的一组函数，直接对字符缓冲区操作：

```cpp
#include <charconv>

int v = 0;
auto [ptr, ec] = std::from_chars(s.data(), s.data() + s.size(), v);
if (ec == std::errc{}) {
    // 解析成功；ptr 指向第一个未消费的字符
}
```

对比 `stoi`，它的优势很明显：

| | `std::stoi` | `std::from_chars` |
| --- | --- | --- |
| 失败方式 | 抛异常 | 返回 `errc` |
| 内存分配 | `const char*` 入参会构造临时 `string` | 无 |
| locale | 受当前 C locale 影响 | 完全无关 |
| 尾部垃圾 | 默认不检查 | `ptr` 直接给出位置 |
| 前导空白 | 跳过 | **不跳过** |
| `+` 号 | 接受 | **不接受** |
| 性能 | 较慢 | 最快（无异常、无分配、无 locale） |

注意 `from_chars` 的语义更"严格"：不跳空白、不认 `+`。所以 `from_chars` 适合解析**已经
清洗过**的字段；`stoi` 适合手写输入那种宽松场景。浮点版本的 `from_chars`/`to_chars` 在
GCC 11 之前支持不完整，老编译器上要测一下。

顺带一句：`PQgetvalue` 返回 `const char*` 时，`std::stoi` 会先构造一个临时 `std::string`
（一次堆分配），再解析。字段多的话，用 `from_chars` 直接吃指针可以省掉这次分配：

```cpp
const char* val = PQgetvalue(res, i, 4);
int v = 0;
std::from_chars(val, val + std::strlen(val), v);
```

## 顺带一提：下标越界

上面 `parts[4]` 的写法有个前提——`parts.size() >= 6`。切分结果短于预期时（比如那行
少了一个字段），`operator[]` 是**未定义行为**，不抛异常、不报错，读到的可能是垃圾值。
和上篇的切分函数配合使用时，先 `if (parts.size() != kFieldCount) continue;` 再取值，
否则 `try/catch` 拦不住越界——它压根不是异常。

另外 `PQgetvalue` 对 SQL NULL 字段返回的是**空字符串**（不是 `nullptr`），判断 NULL 要用
`PQgetisnull`。直接把空串喂给 `stoi` 就是 `invalid_argument`，前面那层 `try/catch` 会兜住，
但语义上是"该字段为 NULL"而非"格式错误"，两者最好分开处理。

## 小结

- 文本 → 数字用 `std::stoi` 家族，失败抛异常，外部输入必须 catch
- `stoi` 默认不检查尾部垃圾，传 `pos` 才能做严格解析
- 十进制解析显式写 `base = 10`，`base = 0` 会把 `"010"` 当八进制
- `to_string` 的浮点版本固定 6 位小数、受 locale 影响，持久化场景别用
- 性能敏感或无异常环境用 `from_chars` / `to_chars`：零分配、locale 无关、最快
- 取值前先校验 `parts.size()`——越界不是异常，`try/catch` 救不了
