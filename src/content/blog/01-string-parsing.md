---
title: "字符串按分隔符切分（find + substr）"
description: "手工用 std::string::find + substr 把定界文本行切成字段"
date: 2026-08-15
tags: [cpp, string, parsing]
type: note
topic: "C++"
---

# 字符串按分隔符切分（find + substr）

## Concept
手工用 `std::string::find` + `substr` 把一行文本按分隔符切成多个字段。
- **是什么**：`s.find(ch, start)` 从 `start` 位置向后找字符 `ch`，返回下标或 `npos`；`s.substr(pos, len)` 截取子串。配合循环，一行 `A|B|C` 变成三个字段。
- **解决什么问题**：项目数据文件 `students.txt` 每行是 `studentId|name|className|...`，`deserialize` 要把它还原成 `StudentRecord`。
- **在体系中的位置**：实体层（models）的解析基础——文件/数据库读进来的原始文本，都要经过它变成结构体。

## Why
- **为何需要**：程序读进来的是一行字节，不是结构体。必须有"文本 ↔ 结构体"的桥。
- **与相关概念的区别**：`std::istringstream` + `std::getline(ss, tok, '|')` 也能切分，但 `find`/`substr` 能精确知道"第几个字段"的位置，调试时更直观。
- **若不用会怎样**：字段数对不上、空字段、越界取值全乱套。

## Example（项目真实代码 `src/models/StudentRecord.cpp`）
```cpp
std::vector<std::string> parts;
size_t start = 0;
while (true) {
    size_t pos = s.find(kFieldSep, start);   // 找下一个 |
    if (pos == std::string::npos) {          // 没有更多分隔符了
        parts.push_back(s.substr(start));    // 剩下的就是最后一个字段
        break;
    }
    parts.push_back(s.substr(start, pos - start));  // 截取 start..pos 之间的字段
    start = pos + 1;                          // 跳过这个分隔符继续
}
```
**为什么这么写**：`npos` 是哨兵（极大值），表示"找不到"；字段用"两个 `|` 之间的子串"表达，最后一个字段用"从 start 到结尾"。循环终止条件是"没有更多分隔符"而非"数够了"——这样字段数不管多少都能切。

## General Pattern
解析任何"定界文本行"（CSV、日志、配置）的通用套路：
1. 循环 `find(sep, start)`，`start` 每次跳到 `pos + 1`
2. 命中 `npos` 时取剩余段并 break
3. 切完后**校验字段个数**，再逐字段转换类型

## Common Mistakes（真实踩过）
- **用错常量**：`s.find(kFieldCount, start)` 把整数 7 当成字符去搜（ASCII 7 是控制字符），永远搜不到 → 整行当一个字段 → 所有记录解析失败，表现为"共加载 0 条记录"。教训：`kFieldSep`（分隔符）和 `kFieldCount`（个数）名字像，极易混用。
- **切分后不校验个数**就直接 `parts[4]`——字段少了会越界。

## Related Concepts
- [[02-stoi-to-string]]（切出来的文本要转数字）
- [[04-serialize-deserialize]]（反向操作：拼一行）
- CRLF 处理（`\r` 留在行尾要先 `pop_back`）

## Status
Practiced
