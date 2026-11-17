---
title: "第 0 步：NumPy 函数速查（做实验前先热手）"
description: "axis=0 是'沿着行往下走'，所以结果里不再有行；axis=1 是'沿着列往右走'，结果里不再有列。"
date: 2026-10-19
tags: [deep-learning, numpy]
type: note
topic: "深度学习"
---

> 配套脚本：`learn/practice/numpy_warmup.py`
>
> 这份文档不要求背。写代码时遇到 `axis`、`argmax`、`arange`、`keepdims` 拿不准，回来查表即可。
> 每个函数都给出：**作用 → 形状变化 → 小例子 → 坑**。

## 1. 先记住一件事：axis 是"被消掉的那一维"

```python
X = np.array([[1, 2, 3],
              [4, 5, 6]])      # shape (2, 3)
```

| 写法 | 结果 | 形状 | 记忆 |
|---|---|---|---|
| `X.sum()` | `21` | 标量 | 全部加起来 |
| `X.sum(axis=0)` | `[5, 7, 9]` | `(3,)` | 消掉第 0 维（行），对每列求和 |
| `X.sum(axis=1)` | `[6, 15]` | `(2,)` | 消掉第 1 维（列），对每行求和 |
| `X.sum(axis=0, keepdims=True)` | `[[5, 7, 9]]` | `(1, 3)` | 保留维度，方便广播 |
| `X.max(axis=1)` | `[3, 6]` | `(2,)` | 每行最大值 |
| `X.argmax(axis=1)` | `[2, 5]` | `(2,)` | 每行最大值的位置 |

`axis=0` 是"沿着行往下走"，所以结果里不再有行；`axis=1` 是"沿着列往右走"，结果里不再有列。

**为什么需要 `keepdims=True`？** 因为 `(N, C) - (N,)` 不能按你想象的方式广播。看第 6 节。

## 2. 创建数组：zeros / ones / eye / arange / linspace

```python
np.zeros((3, 4))          # 3x4 全 0，float64
np.ones(5)                # [1 1 1 1 1]，shape (5,)
np.eye(4)                 # 4x4 单位矩阵
np.arange(5)              # [0 1 2 3 4]
np.arange(1, 6)           # [1 2 3 4 5]，不含 6
np.arange(0, 1, 0.25)     # [0, 0.25, 0.5, 0.75]，可以有小数步长
np.linspace(0, 1, 5)      # [0, 0.25, 0.5, 0.75, 1]，含两端，共 5 个
```

- `range` 是 Python 的迭代器，`np.arange` 返回可以直接做运算的数组。
- `np.arange(n)` 最常见的用途是生成"行号"，见第 5 节。

## 3. 聚合函数：sum / mean / max / argmax / std

```python
X.sum(axis=0)       # 按列求和
X.mean(axis=1)      # 按行求平均
X.max(axis=1)       # 按行最大值
X.argmax(axis=1)    # 按行最大值的下标
X.std()             # 全体标准差
np.abs(X)           # 逐元素绝对值
np.isfinite(X)      # 逐元素判断是否是有限值，返回布尔数组
np.all(np.isfinite(X))   # 是否全部有限（用来检查 NaN/inf）
```

**`argmax` 返回的是下标，不是值。** 分类器最后一步 `predict` 就是：每个样本的 10 个打分里，哪个下标最大，就预测哪一类。

```python
Z = np.array([[0.2, 0.5, 0.3],
              [0.9, 0.05, 0.05]])
Z.argmax(axis=1)   # array([1, 0]) -> 第一个样本预测 1，第二个预测 0
```

平局时 `argmax` 返回第一个最大值的下标，这一点在初始化全零时会出现（所有类别打分为 0，于是永远预测第 0 类）。

## 4. 索引：切片 / 布尔掩码 / 花式索引

```python
X[0]          # 第 0 行，shape (D,)
X[:, 0]       # 第 0 列，shape (N,)
X[:5]         # 前 5 行
X[-1]         # 最后一行
```

**布尔掩码**：先算一个布尔数组，再用它选行。

```python
y = np.array([0, 2, 1, 2, 0])
mask = (y == 2)          # [False, True, False, True, False]
X[mask]                  # 只保留 y==2 的那些行，shape (2, D)
np.flatnonzero(mask)     # 这些行的下标：[1, 3]
```

**花式索引**（fancy indexing）：用整数数组一次取多个位置。

```python
y = np.array([2, 0, 1])
idx = np.array([0, 1, 2])
P[idx, y]        # 取 P[0,2], P[1,0], P[2,1]
P[:, y]          # 注意！这是取第 2、0、1 列，shape (N, 3)，不是你要的
```

为什么 `P[:, y]` 不对？因为 `:` 表示"所有行"，`y` 表示"这些列"，结果是 `(N, len(y))` 的矩阵。要取"第 0 行第 y[0] 列、第 1 行第 y[1] 列"，必须让行下标和列下标一一配对：

```python
P[np.arange(len(y)), y]     # 正确，shape (len(y),)
```

这就是 `np.arange` 在交叉熵里出现的原因。

## 5. one-hot 与"按标签取概率"

```python
C = 4
y = np.array([2, 0, 3])
np.eye(C)          # 4x4 单位矩阵
np.eye(C)[y]       # shape (3, 4)，第 i 行是 y[i] 的 one-hot
```

结果：

```
[[0. 0. 1. 0.]
 [1. 0. 0. 0.]
 [0. 0. 0. 1.]]
```

于是交叉熵里的 `P[np.arange(N), y]` 就是"每个样本真实类别的预测概率"，形状 `(N,)`。

**不要用 `P[:, y]` 代替它**，原因见上一节。

## 6. 广播（broadcasting）：形状不同也能运算

规则：从**最后**一维开始对齐，每一维必须"相等"或"其中一个是 1"，否则报错。

```python
A = np.zeros((4, 3))          # (4, 3)

A - np.array([1, 2, 3])       # (3,) -> 看成 (1, 3)，广播到每一行
A - np.array([[1], [2], [3], [4]])   # (4, 1) -> 每一行减自己的数
A - np.array([1, 2, 3, 4])    # 报错：(4,3) 与 (4,) 最后一维 3 vs 4
```

softmax 里必须写成：

```python
m = logits.max(axis=1, keepdims=True)   # (N, 1)
z = logits - m                          # (N, C) - (N, 1) -> (N, C)
```

如果 `keepdims` 忘了写，`m` 是 `(N,)`，`(N,C) - (N,)` 只在 `C == N` 时才能跑，而且算出来是错的（它减的是每一列，不是每一行）。

## 7. 矩阵乘法：`@` 不是 `*`

```python
X = np.zeros((N, D))
W = np.zeros((D, C))

Z = X @ W          # (N,D) @ (D,C) -> (N,C)，矩阵乘法
Z = X * W          # 逐元素乘，要求形状可广播；这里 D != C 会报错
```

| 写法 | 含义 | 形状 |
|---|---|---|
| `X @ W` | 矩阵乘 | `(N,D) @ (D,C) -> (N,C)` |
| `X.T @ dZ` | 转置后矩阵乘 | `(D,N) @ (N,C) -> (D,C)` |
| `X * W` | 逐元素乘 | 要求形状相同或可广播 |
| `X.T` | 转置 | `(N,D) -> (D,N)` |

反向传播里几乎所有错误都能归结为"把 `@` 写成了 `*`"或"转置放错位置"。

## 8. exp / log 与数值稳定

```python
np.exp(np.array([1000.0]))     # inf（溢出，RuntimeWarning）
np.log(0.0)                    # -inf（RuntimeWarning）
np.log(np.array([1.0, np.e]))  # [0, 1]
```

数值稳定的 softmax：

```python
m = logits.max(axis=1, keepdims=True)
e = np.exp(logits - m)         # 最大值变成 exp(0)=1，不会溢出
p = e / e.sum(axis=1, keepdims=True)
```

数值稳定的交叉熵（log-sum-exp）：

```python
m = logits.max(axis=1, keepdims=True)
shifted = logits - m
logsumexp = np.log(np.exp(shifted).sum(axis=1)) + m[:, 0]   # (N,)
loss_n = logsumexp - logits[np.arange(N), y]                # 每个样本的损失
loss = loss_n.mean()
```

如果直接写 `loss = -np.log(P[np.arange(N), y]).mean()`，概率很小时会得到 `inf`，训练立刻变成 `nan`。

## 9. 随机数：`default_rng`

```python
rng = np.random.default_rng(0)          # 固定种子，结果可复现

rng.normal(0, 1, size=(3, 2))           # 均值 0、标准差 1 的正态
rng.uniform(0, 1, size=5)               # [0,1) 均匀
rng.integers(0, 4, size=10)             # [0,4) 的整数，不含 4
rng.permutation(5)                      # 0..4 的随机排列
rng.choice(10, size=3, replace=False)   # 从 0..9 不重复抽 3 个
```

- 旧写法 `np.random.seed(0); np.random.randn(...)` 也能用，但新代码推荐 `default_rng`。
- 随机种子只影响"随机"，不影响公式；结果对不上时先检查种子。

## 10. 拼接、网格与常用小函数

```python
np.vstack([X1, X2])          # 按行堆叠，(N1,D)+(N2,D) -> (N1+N2,D)
np.hstack([X1, X2])          # 按列堆叠，D 相加
np.column_stack([x, y])      # 两个 (N,) -> (N,2)
np.concatenate([a, b])       # 沿指定 axis 拼接

np.linspace(-3, 3, 100)      # 100 个等距点
xx, yy = np.meshgrid(np.linspace(-3, 3, 100),
                     np.linspace(-3, 3, 100))
# xx, yy 都是 (100,100)，用来画决策边界
grid = np.column_stack([xx.ravel(), yy.ravel()])   # (10000, 2)

np.unique(y)                 # 排序后的唯一值
np.bincount(y)               # 每个整数出现几次（要求非负整数）
np.argsort(x)                # 从小到大排序后的下标
np.linalg.norm(W)            # 矩阵/向量的 Frobenius / L2 范数
```

`np.add.at(cm, (y_true, y_pred), 1)` 是"带重复下标的累加"：普通 `cm[i, j] += 1` 在重复索引时只加一次，`np.add.at` 会把每次出现都加上。混淆矩阵用它来统计。

## 11. 报错 → 原因 对照表

| 报错 / 现象 | 常见原因 |
|---|---|
| `operands could not be broadcast together with shapes (100,4) (100,)` | 忘了 `keepdims=True`，或把 `(N,C)` 和 `(N,)` 相减 |
| `shapes (2,4) and (4,2) not aligned` | 矩阵乘法维度没对上，检查 `@` 两边 |
| 损失变成 `nan` | `log(0)`、`exp` 溢出、学习率太大 |
| 损失一直是 `1.386` | 四类均匀分布，模型没学到东西 |
| 梯度检查误差 `1e-2` 量级 | 少了 `/N`、L2 只加一边、转置错误 |
| `IndexError: index 4 is out of bounds` | 类别下标从 0 开始，`C=4` 时最大下标是 3 |
| `predict` 永远输出 0 | 权重全零且没有打破对称性（MLP 的零初始化会这样） |
| 训练准确率 1.0 但测试很低 | 过拟合：模型在背训练集 |

## 12. 热手练习

运行：

```bash
cd learn/practice
python numpy_warmup.py
```

脚本里有 6 个小任务，都是上面这些函数的直接应用。全部 PASS 后再做第 1 步。任务本身不涉及机器学习，只练"看形状、选 axis、配对下标"。

---

**速记**：

- `axis=0` 消掉行，`axis=1` 消掉列；
- 广播从最后一维对齐，差一维就 `keepdims`；
- 取"每行一个元素"用 `P[np.arange(N), y]`，不要用 `P[:, y]`；
- 矩阵乘用 `@`，逐元素用 `*`；
- 先减最大值，再 `exp`；先 `logsumexp`，再算损失。
