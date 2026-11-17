---
title: "字符串按分隔符切分"
description: "用 std::string::find + substr 把定界文本行切成字段"
date: 2026-08-15
tags: [cpp, string, parsing]
type: note
topic: "C++"
---

# 字符串按分隔符切分（find + substr）

## Concept
标准库没有 `std::string::split`。解析定界文本（CSV、配置文件、日志行）时，最直接的写法就是`find` 找下一个分隔符、`substr` 截取字段，然后从分隔符之后继续找——直到 `find` 返回
`std::string::npos` 表示"没有更多分隔符了"。


## Example
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

注意最后一行硬编码的 + 1：它只对单字符分隔符成立。如果 kFieldSep 是 "||" 这种多字符分隔符，正确写法是 start = pos + kFieldSep.size()，否则会把分隔符的尾巴吃进下一个字段。

## 更多实际用途
在本人做的一个课程项目中，HTTP 请求解析器的请求行就是按空格切分成 method / target / version 三段，然后从 target 拆出 host / port / path, 此时就可以用上面的 find + substr 循环：

```cpp
bool parseRequest(const std::string &raw, HttpRequest &out) {
    // TODO 1: 逐行切开（分隔符 "\r\n"），第一行是请求行
    std::string::size_type pos = raw.find("\r\n");
    if (pos == std::string::npos) {
        return false; // 没有找到请求行
    }
    std::string requestLine = raw.substr(0, pos);

    // TODO 2: 请求行按空格切成三段：method / target / version
    std::string::size_type firstSpace = requestLine.find(' ');
    if (firstSpace == std::string::npos) {
        return false; // 没有找到第一个空格
    }
    std::string::size_type secondSpace = requestLine.find(' ', firstSpace + 1);
    if (secondSpace == std::string::npos) {
        return false; // 没有找到第二个空格
    }
    out.method = requestLine.substr(0, firstSpace);
    std::string target =
        requestLine.substr(firstSpace + 1, secondSpace - firstSpace - 1);
    out.version = requestLine.substr(secondSpace + 1);

    // TODO 3: 从 target 拆出 host / port / path
    //           - 跳过开头的 "http://"
    //           - host 之后若出现 ":"，冒号后是端口号
    //           - 第一个 "/" 起是 path（连同后面的 query）；没有 "/" 则 path =
    //           "/"

    // Get host

    std::string::size_type hostStart = 0;
    if (target.compare(0, 7, "http://") == 0) {
        hostStart = 7;
    }
    std::string::size_type pathStart = target.find('/', hostStart);
    std::string hostPort;
    if (pathStart != std::string::npos) {
        hostPort = target.substr(hostStart, pathStart - hostStart);
        out.path = target.substr(pathStart);
    } else {
        hostPort = target.substr(hostStart);
        out.path = "/";
    }

    // Check for port
    std::string::size_type colonPos = hostPort.find(':');
    if (colonPos != std::string::npos) {
        out.host = hostPort.substr(0, colonPos);
        std::string portStr = hostPort.substr(colonPos + 1);
        try {
            out.port = std::stoi(portStr);
        } catch (const std::exception &) {
            return false; // Invalid port number
        }
    } else {
        out.host = hostPort;
        out.port = 80; // Default port
    }

    return true;
}

```

## 封装成函数
使用中把循环收进函数，顺便把分隔符类型放宽到 std::string，这样单字符和多字符都能覆盖
```cpp
#include <string>
#include <vector>

std::vector<std::string> split(const std::string& s, const std::string& sep) {
    std::vector<std::string> parts;
    if (sep.empty()) return {s};          // 空分隔符无从切分，原样返回

    size_t start = 0;
    while (true) {
        size_t pos = s.find(sep, start);
        if (pos == std::string::npos) {
            parts.push_back(s.substr(start));
            break;
        }
        parts.push_back(s.substr(start, pos - start));
        start = pos + sep.size();
    }
    return parts;
}
```
如果分隔符确定是单字符，用 s.find('|', start) 而不是 s.find("|", start)：前者走的是char_traits::find 的单元素路径，省掉一次 strlen，在超长行上肉眼可见地快。

## 进一步优化
但是上面的版本每个字段都要 substr 一次，即一次堆分配。字段多、行短时这是主要的开销来源。 换成 std::string_view 只返回指向原缓冲区的"视图"，全程零拷贝
```cpp
#include <string_view>
#include <vector>

std::vector<std::string_view> split_view(std::string_view s, std::string_view sep) {
    std::vector<std::string_view> parts;
    if (sep.empty()) return {s};

    size_t start = 0;
    while (true) {
        size_t pos = s.find(sep, start);
        if (pos == std::string_view::npos) {
            parts.push_back(s.substr(start));
            break;
        }
        parts.push_back(s.substr(start, pos - start));
        start = pos + sep.size();
    }
    return parts;
}
```

## C++20 的 ranges::views::split
C++20 之后标准库终于有了官方切分，惰性求值、不分配内存：
```cpp
#include <ranges>

for (auto part : line | std::views::split('|')) {
    std::string_view field(part.begin(), part.end());  // 注意：part 不是 string_view
    handle(field);
}
```

两个注意点：split 的每个元素是子 range 而不是 string_view，要自己用 begin()/end()构造；另外 C++20 里对 std::string 用 views::split 时结果不满足 common_range，某些算法需要额外套 std::views::common。能用上面的手写版本就先用手写版本，依赖更少、
