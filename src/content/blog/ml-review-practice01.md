---
title: "练习 01 代码 review"
description: "被检查的文件：learn/practice01.py"
date: 2026-10-12
tags: [machine-learning, code-review]
type: note
topic: "机器学习"
---

被检查的文件：`learn/practice01.py`

整体评价：函数的划分和 docstring 写得比我预期的规范（每个函数都有参数与返回值的说明），`calculate_contribution` 里"总距离平方和"与"各维贡献"分开累加的思路也是对的。问题集中在三类：**无法运行的语法错误**、**函数偷偷修改输入**（这类 bug 最危险，因为它不报错、结果还像是对的）、以及**函数设计与练习要求不匹配**。下面按"先讲原因、再给修法"的顺序说。

## 一、三个让程序完全跑不起来的问题

### 1. import 语法错误（第 4 行）

```python
import ../code/data_gen.py as dg
```

报错是 `SyntaxError: invalid syntax`。这里你把 C++ 的 `#include "../code/data_gen.h"` 习惯直接搬到 Python 了，但两者的机制完全不同。

C++ 的 `#include` 是**文本预处理**：预处理器把那个头文件的全部内容原样粘贴到这一行，所以路径是"相对于当前文件"的文件路径，而且要写清文件名和后缀。Python 的 `import` 是**运行时模块查找**：`import data_gen` 里的 `data_gen` 是一个**模块名**（对应 `data_gen.py` 这个文件，但写的时候不带 `.py`），Python 到 `sys.path` 列表里的每个目录下去找它。路径不是 import 语句的一部分，语法上也不允许出现 `../`。

所以要做两件事：把目录加进 `sys.path`，然后 import 模块名。

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "code"))
import data_gen as dg
```

几点说明。`Path(__file__).resolve().parent` 拿到本文件所在目录（也就是 `learn/`），`.parent` 再上一层到 `experiment3/`，拼上 `"code"` 就是目标目录。用绝对路径而不是 `"../code"` 的原因是：相对路径是相对**当前工作目录**解析的，你在 `learn/` 下运行没问题，但从别处运行（比如 `python learn/practice01.py`）就会找不到。`make_fig01.py` 里用的是同样的写法，可以参考。

顺带一提，`import numpy` 没问题，但大家习惯写 `import numpy as np`，后面代码短一些。

### 2. `load_dataset` 的返回值是三元组，不是数组

```python
dataset = dg.load_dataset("iris_2d")
...
dataset.copy()          # AttributeError: 'tuple' object has no attribute 'copy'
```

`load_dataset` 返回 `(X, y, feature_names)` 三样东西：特征矩阵、标签、特征名。这样设计是因为讲义里反复强调"聚类用不到标签，但事后要拿标签做对照"——所以标签必须能拿到，但不能混进特征里。你要的是第一个：

```python
X, y, feature_names = dg.load_dataset("iris_2d")
```

用 `X, y, _ = ...` 也可以（`_` 表示"我不关心这个"）。建议保留 `feature_names`，因为调试时打印出来能立刻看出哪列是哪列——你这次就是被"iris_2d 其实只有两列"这件事绊了一下（详见第三节）。

### 3. 同一个变量载入了两次

第 6 行（模块顶层）和第 79 行（`__main__` 里）各载入了一次。第二次会覆盖第一次，结果上不会出错，但读代码的人会困惑"到底用哪个"。保留 `__main__` 里的那次即可，模块顶层那句删掉。

## 二、最危险的问题：`calculate_contribution` 修改了它的输入

这是这次 review 里最值得记住的一个坑。你的函数里有这么一行（第 60 行）：

```python
dataset[:, 0] *= 1000
```

这是**原地操作**：`dataset[:, 0] *= 1000` 等价于 `dataset[:, 0] = dataset[:, 0] * 1000`，它直接改写了传进来的那个数组的内容。函数签名上完全没有体现这件事——调用者看到 `calculate_contribution(data)`，会以为只是"算一下"，不会想到 `data` 已经被改了。

后果是**两层叠加**，让输出看起来对、实际全错：

- 主程序第 82 行 `calculate_contribution(dataset.copy())`：虽然传的是副本，但函数内部把副本的第 0 列乘了 1000。所以这个变量名叫 `contributions_before`（"缩放前"），打印出来的却**已经**是缩放后的结果 `[1.0, 0.0]`。
- 主程序第 86 行又手动 `dataset[:, 0] *= 1000`，第 88 行再次调用函数，函数内部**又**乘一次。实际算的是 $1000\times1000=10^6$ 倍。
- 于是两个结果都显示 `[1.0, 0.0]`，差别小到看不出来，很容易误以为"实验成功了"。

我实际跑了一遍你的代码（只修了前三个问题，逻辑一字未动），输出是：

```
Contributions before scaling: [9.99999813e-01 1.87080194e-07]
Contributions after scaling: [1.00000000e+00 1.87080229e-13]
```

`before` 就已经接近 100% 了，这正是双重缩放的痕迹。而**正确的"缩放前"应该是**：

```
原始数据（iris_2d 只有两列）: [0.8424, 0.1576]
```

这是两个必须分开的现象，别混在一起：`[0.8424, 0.1576]` 是"花瓣长本来就占 84%"（真实存在的量纲问题）；而 `[1.0, 0.0000001]` 是"你的函数把数据乘了 1000 倍"（人为制造的）。

**为什么原地修改是坏习惯。** 除了这次的自乘两次，它还会在更大的程序里造成难查的 bug：调用者传进去的数组在别处还要用，结果被悄悄改了；或者函数被调用两次，第二次的结果和第一次不同（因为输入变了）。C++ 里你会用 `const std::vector<double>&` 来承诺"我不改你的参数"，Python 没有 `const`，所以这个承诺只能靠**编码习惯**来保证：**函数内部要用到修改后的数据，就先复制一份再改；不要改参数本身。**

```python
def contributions(data):
    """不修改传入的 data。缩放请在函数外面做。"""
    n_features = data.shape[1]
    total = 0.0
    contrib = np.zeros(n_features)
    for i in range(len(data)):
        for j in range(i + 1, len(data)):
            diff = data[i] - data[j]
            total += np.sum(diff ** 2)
            contrib += diff ** 2          # (a-b)^2 逐维相加
    return contrib / total
```

缩放的职责交给调用者：

```python
X_before = contributions(X)

X_scaled = X.copy()          # 复制！不要动原来的 X
X_scaled[:, 0] *= 1000
X_after = contributions(X_scaled)
```

注意 `contrib += diff ** 2` 这一句同时解决了另一个小问题：你原来内层又套了一个 `for k in range(num_features)` 循环，而 NumPy 数组的 `+`、`**`、`*` 都是**逐元素**运算，直接对整个数组做就行。这样代码短了，速度也快了（Python 的显式循环比 NumPy 的向量化慢得多）。你原来写 `contributions[k] += (dataset[i][k] - dataset[j][k]) ** 2` 语法上没错，但没必要。

## 三、函数设计与练习要求不匹配

### `calculate_distance` 只支持一维

```python
return numpy.sqrt(numpy.sum((sample1[index] - sample2[index]) ** 2))
```

练习 2 要求算两种距离："只看花瓣长度"和"两列都用"。你现在这个函数只能做前一种——`sample1[index]` 取出的是一个**标量**，对它求平方和，结果就是 $|x_i-z_i|$（一维距离）。

问题在于参数名叫 `index`（单数），语义上就跟"一组特征"冲突了。改进方式是让 `feature_indices` 支持一个列表，一次取多列：

```python
def calculate_distance(sample1, sample2, feature_indices):
    """feature_indices 可以传 [0]（只看花瓣长）或 [0, 1]（两列都用）。"""
    a = sample1[feature_indices]      # 用列表索引，取出的是一个子向量
    b = sample2[feature_indices]
    diff = a - b
    return np.sqrt(np.sum(diff ** 2))
```

这就是 NumPy "fancy indexing" 的用法：`arr[[0, 1]]` 取出第 0、1 列组成新数组，而 `arr[0]` 只取出第 0 列的元素。你现在的写法如果传 `index=[0, 1]`，`sample1[[0,1]]` 得到的是两元素数组，`** 2` 后求和再开方，**居然也能给出正确答案**——但那是碰巧，因为它把两次调用合并成了一次求和。真正的区别在于这个函数会变得无法单独检查"某一维的距离"，所以还是改成显式支持列表更好。

顺便说一句：`(a - b) ** 2` 外面再 `numpy.sum` 再 `numpy.sqrt` 是对的，但注意 `numpy.sqrt(numpy.sum(...))` 和 `numpy.sum(...) ** 0.5` 等价，选一种就行。

### `exactract_features` 有两个问题

第一，函数名拼错了，应该是 `extract_features`。

第二，**函数名和职能不符**。名字叫"提取特征"，但它实际上做了两件事：提取指定的列，然后标准化。更严重的是，它默认做标准化——练习 3 要的正是标准化，但练习 4 要对比"标准化前/后"，如果提取和标准化绑在一起，就没法单独拿到"未标准化的若干列"了。建议拆成两个函数：

```python
def extract_features(data, feature_indices):
    return data[:, feature_indices]        # 只取列，不做别的

def standardize(data):
    mean = data.mean(axis=0)
    std = data.std(axis=0)
    safe = std > 1e-12                     # 防止常数列除零
    out = np.zeros_like(data)
    out[:, safe] = (data[:, safe] - mean[safe]) / std[safe]
    return out
```

`safe` 那两行处理的是"某一列所有值都相同"的情况（标准差为 0），此时除法会得到 `nan`。真实数据集里这种列很常见（比如 optdigits 的 8x8 图像里有若干边界像素永远是 0），所以这个防护值得养成习惯。你可以先用不含防护的版本做练习 3（Iris 没有常数列，不会触发），但知道有这回事。

### 缺少练习 1 和练习 5

练习 1（画散点图）和练习 5（一维数据手工分三组）在文件里没有体现。练习 5 尤其重要——它是下一讲 k-means 的引子，先自己想"怎么分"，再看算法的做法，对照效果最好。

## 四、一个顺带修正：讲义里的数字有个错

你在练习 4 里拿 `iris_2d` 做实验，而讲义第 5 节引用的 `0.150 0.041 0.681 0.127` 是 **`iris_4d`（四个特征）**的数字。这两个数据集不同，数字当然不同：

| 数据 | 原始占比 | 第 0 列 x1000 | 标准化后 |
|---|---|---|---|
| `iris_4d`（4 列） | 0.150, 0.041, **0.681**, 0.127 | 1.0, 0, 0, 0 | 0.25 × 4 |
| `iris_2d`（2 列） | **0.8424**, 0.1576 | 1.0, 0 | 0.5, 0.5 |

同时讲义里那句"第 2 列（花瓣长度）独自占了 68%"是错的：`0.681` 是第 2 列的占比没错，但索引从 0 数起，`iris_4d` 的第 2 列是 `petal_length`——这里其实是巧合对上了，但表述容易让人以为只有四个特征时才需要标准化。我已经把讲义改成明确标出"`iris_4d` 四个特征"并把索引改成 `第 2 列（索引 2）`，避免歧义。

顺带一个值得注意的点：`iris_2d` 里花瓣长单独占 **84%**，比四特征时的 68% 还高。这说明**去掉特征不改变量纲问题，反而可能让它更严重**。

## 五、修改后的完整参考

把上面的意见合起来，一个可以运行的版本如下。请注意这不是"标准答案"，尤其练习 5 我没有代做。

```python
#!/usr/bin/env python
# coding=utf-8
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "code"))
import data_gen as dg


def calculate_distance(sample1, sample2, feature_indices):
    """两个样本在指定特征上的欧氏距离。

    feature_indices 传 [0] 只看第 0 列，传 [0, 1] 则两列一起算。
    """
    diff = sample1[feature_indices] - sample2[feature_indices]
    return float(np.sqrt(np.sum(diff ** 2)))


def extract_features(data, feature_indices):
    """只做取列，不做标准化。"""
    return data[:, feature_indices]


def standardize(data):
    """按列 z-score。常数列（标准差为 0）置 0，避免除零产生 nan。"""
    mean = data.mean(axis=0)
    std = data.std(axis=0)
    safe = std > 1e-12
    out = np.zeros_like(data)
    out[:, safe] = (data[:, safe] - mean[safe]) / std[safe]
    return out


def contributions(data):
    """每一维对全部两两距离平方和的贡献占比。不修改传入的 data。"""
    n_features = data.shape[1]
    total = 0.0
    contrib = np.zeros(n_features)
    for i in range(len(data)):
        for j in range(i + 1, len(data)):
            diff = data[i] - data[j]
            total += np.sum(diff ** 2)
            contrib += diff ** 2
    return contrib / total


if __name__ == "__main__":
    X, y, feature_names = dg.load_dataset("iris_2d", standardize=False)
    print("特征:", feature_names, " 形状:", X.shape)

    # 练习 2：两种距离
    print("只看花瓣长 [0]  :", round(calculate_distance(X[0], X[60], [0]), 4))
    print("两列都用 [0, 1]:", round(calculate_distance(X[0], X[60], [0, 1]), 4))

    # 练习 3：标准化
    X_std = standardize(extract_features(X, [0, 1]))
    print("标准化后 均值:", np.abs(X_std.mean(axis=0)).round(10),
          " 标准差:", X_std.std(axis=0).round(10))

    # 练习 4：占比对比（注意 X.copy()，不要污染原始数据）
    print("原始占比        :", contributions(X).round(4))
    X_scaled = X.copy()
    X_scaled[:, 0] *= 1000
    print("第 0 列 x1000 后 :", contributions(X_scaled).round(4))
    print("标准化后占比    :", contributions(X_std).round(4))

    # 练习 1：画图（需要 matplotlib）
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    # 中文字体：不设置的话图上的中文会变成方框（Glyph missing from font）
    plt.rcParams["font.sans-serif"] = ["Noto Sans CJK SC", "AR PL UMing CN", "DejaVu Sans"]
    plt.rcParams["axes.unicode_minus"] = False
    fig, ax = plt.subplots(figsize=(6, 5))
    for j, c in enumerate(["setosa", "versicolor", "virginica"]):
        ax.scatter(X[y == j, 0], X[y == j, 1], s=30, alpha=0.75, label=c)
    ax.set_xlabel(feature_names[0])
    ax.set_ylabel(feature_names[1])
    ax.set_title("练习 1：三个品种的二维分布")
    ax.legend()
    fig.savefig("figures/practice01_scatter.png", bbox_inches="tight")
    print("图已保存到 figures/practice01_scatter.png")
```

跑出来的结果应该是：

```
特征: ['petal_length', 'petal_width']  形状: (150, 2)
只看花瓣长 [0]  : 2.1
两列都用 [0, 1]: 2.2472
标准化后 均值: [0. 0.]  标准差: [1. 1.]
原始占比        : [0.8424 0.1576]
第 0 列 x1000 后 : [1. 0.]
标准化后占比    : [0.5 0.5]
```

对照着看这几个数：两列距离（2.2472）比只看一列（2.1）大，这是必然的——多算了一维的差，平方和只会变大。标准化后两列占比都是 0.5，说明它们对距离的贡献变得完全对等（原始是 0.84 对 0.16）。

注意 X[0] 是 setosa、X[60] 是 versicolor，它们的花瓣长差了 2.1 cm。这个差距已经接近 setosa 整列的取值范围（1.0–1.9），所以"空白区"在数值上就是这么来的。

## 六、这次练习值得记住的几点

函数不要偷偷修改传入的参数。Python 没有 `const`，这个约定只能靠习惯维持。判断标准很简单：**函数体里出现了 `参数[...] = `、`参数[...] *= `、`参数.append(...)` 这类写法，就是在改调用者的数据**，除非函数名明确说了"就地修改"（比如 `sort()` 之于 `sorted()`）。

调试时先打印形状和列名。`X.shape` 是 `(150, 2)` 而不是 `(150, 4)`，一眼就能看出用的不是四特征版本。`feature_names` 同理。这次的困惑有一半来自"我以为在用四列"。

报错信息要顺着读。`'tuple' object has no attribute 'copy'` 直接告诉你 `load_dataset` 返回的不是数组；`SyntaxError` 指出行号，说明 import 那行根本没被解析。Python 的报错通常比 C++ 的模板报错友好得多，值得逐字读。

`import` 和 `#include` 不是一回事。前者按**模块名**在 `sys.path` 里找，后者按**文件路径**做文本替换。混用会让你在路径写法上浪费很多时间。
