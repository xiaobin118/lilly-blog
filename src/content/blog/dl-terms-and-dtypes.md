---
title: "名词、参数与类型标注速查"
description: "Python 的类型标注不参与运行，它只是给人（和编辑器）看的说明书。"
date: 2026-10-19
tags: [deep-learning]
type: note
topic: "深度学习"
---

> 这份文档回答两个问题：
> 1. 代码里那些 `Ws`、`bs`、`fan_in`、`he`、`cache` 到底是什么意思？
> 2. 函数签名里的 `Array`、`-> tuple[float, Array]`、`| None` 怎么读？
>
> 配套代码：`step01_linear.py`、`step02_mlp_forward.py`、`common.py`。

## 1. 先学会读类型标注

Python 的类型标注不参与运行，它只是给人（和编辑器）看的说明书。

```python
def softmax(logits: Array) -> Array:
    ...
```

读作：`softmax` 接收一个叫 `logits` 的参数，类型是 `Array`；返回一个 `Array`。

常见写法：

| 标注 | 含义 | 例子 |
|---|---|---|
| `Array` | NumPy 数组，任意形状 | `X: Array` |
| `int` / `float` / `str` / `bool` | 普通标量 | `seed: int = 0` |
| `list[Array]` | 元素是数组的列表 | `Ws: list[Array]` |
| `tuple[Array, Array, Array]` | 固定 3 个元素的元组 | `(a_prev, z, a)` |
| `tuple[float, Array]` | 一个 float 和一个数组 | `cross_entropy` 的返回值 |
| `Sequence[int]` | 只读的整数序列，list 或 tuple 都行 | `layer_sizes` |
| `Callable[[Array], Array]` | 一个函数：吃 `Array`，吐 `Array` | `predict` 参数 |
| `Array \| None` | 可能是数组，也可能是 `None` | 可选的返回值 |
| `-> None` | 函数不返回有意义的值 | `demo() -> None` |

`from __future__ import annotations` 让这些标注在运行时变成字符串，所以可以写 `Array | None` 而不报错（旧版本 Python 也能用）。

本课程里两个类型别名：

```python
Array = np.ndarray                    # 任意形状的数组
LayerCache = tuple[Array, Array, Array]   # (a_prev, z, a)
ForwardCache = list[LayerCache]           # 每层一个 LayerCache
```

它们不是新类型，只是给长名字起短名字。

## 2. 形状符号表

后面所有讨论都用这几个字母：

| 符号 | 含义 | 例子 |
|---|---|---|
| `N` | 样本数（batch size） | 一次喂 128 张图，N=128 |
| `D` | 输入特征维数 | 二维数据 D=2；MNIST D=784 |
| `C` | 类别数 | 四类 C=4；MNIST C=10 |
| `H` | 隐藏层神经元数 | 128 |
| `fan_in` | 某一层的输入维 | 第一层 fan_in=D |
| `fan_out` | 某一层的输出维 | 第一层 fan_out=H |

形状永远按"行 × 列"写：`X.shape == (N, D)` 表示 N 行、D 列。

## 3. 第 1 步：`LinearClassifier` 的参数

```python
class LinearClassifier:
    def __init__(self, n_features: int, n_classes: int, seed: int = 0) -> None:
```

| 参数 | 类型 | 含义 | 二维例子 | MNIST 例子 |
|---|---|---|---|---|
| `n_features` | `int` | 输入维 D | 2 | 784 |
| `n_classes` | `int` | 类别数 C | 4 | 10 |
| `seed` | `int` | 随机种子；线性模型全零初始化，本步用不到 | 0 | 0 |

对象的属性：

| 属性 | 类型 | 形状 | 含义 |
|---|---|---|---|
| `self.W` | `Array` | `(D, C)` | 每个类别一组权重 |
| `self.b` | `Array` | `(C,)` | 每个类别一个偏置 |

```python
def softmax(logits: Array) -> Array
```
- `logits`：形状 `(N, C)` 的**未归一化打分**，可以是负数。
- 返回：形状 `(N, C)` 的概率，每行和为 1。

```python
def cross_entropy(logits: Array, y: Array) -> tuple[float, Array]
```
- `logits`：`(N, C)`。
- `y`：`(N,)` 的整数标签，每个元素在 `0..C-1`。
- 返回：`(loss, dlogits)`，`loss` 是 Python `float`，`dlogits` 是 `(N, C)`。

```python
def loss_and_grads(self, X: Array, y: Array, l2: float = 0.0) -> tuple[float, Array, Array]
```
- `X`：`(N, D)`；`y`：`(N,)`。
- `l2`：L2 正则系数 λ，`0.0` 表示不正则。
- 返回：`(loss, dW, db)`，形状分别是 `float`、`(D, C)`、`(C,)`。

`train_full_batch` 的参数：

| 参数 | 类型 | 含义 |
|---|---|---|
| `model` | `LinearClassifier` | 要训练的模型，会被原地修改 |
| `X, y` | `Array` | 训练数据 |
| `steps` | `int` | 参数更新多少次 |
| `lr` | `float` | 学习率，每步走多远 |
| `l2` | `float` | L2 系数 |
| `verbose_every` | `int` | 每多少步打印一次损失，0 表示不打印 |

## 4. 第 2 步：`MLP` 的参数

```python
class MLP:
    def __init__(
        self,
        layer_sizes: Sequence[int],
        activation: str = "relu",
        init: str = "he",
        seed: int = 0,
    ) -> None:
```

### `layer_sizes`

**每一层的神经元个数**，按"输入 → 隐藏 → 输出"排列。

```python
MLP([2, 32, 32, 4])        # 输入 2 维 -> 两个 32 维隐藏层 -> 4 类
MLP([784, 128, 10])        # 输入 784 维 -> 128 隐藏 -> 10 类
MLP([784, 256, 128, 10])   # 输入 784 -> 256 -> 128 -> 10
```

长度至少 2。相邻两个数 `(fan_in, fan_out)` 决定一层的形状：

```
[784, 128, 10]
  \   /
 fan_in=784, fan_out=128   -> W1 (784,128), b1 (128,)
       \   /
      fan_in=128, fan_out=10 -> W2 (128,10), b2 (10,)
```

`layer_sizes[:-1]` 是去掉最后一个：`[784, 128]`（每层的输入维）。
`layer_sizes[1:]` 是去掉第一个：`[128, 10]`（每层的输出维）。
`zip` 把两者按位置配对，就是每一层。

### `activation`

隐藏层激活函数的名字，字符串，必须是 `ACTIVATIONS` 的键：

| 值 | 函数 | 特点 |
|---|---|---|
| `"relu"` | `max(0, z)` | 默认；不饱和；约一半单元为 0 |
| `"sigmoid"` | `1/(1+e^{-z})` | 输出 (0,1)；深层容易梯度消失 |
| `"tanh"` | `tanh(z)` | 输出 (-1,1)；零中心 |
| `"linear"` | `z` | 不做非线性，用来验证"塌缩成线性模型" |

输出层**永远不激活**，所以这个参数只影响隐藏层。

### `init`

权重初始化方式，字符串：

| 值 | 公式 | 适合 | 说明 |
|---|---|---|---|
| `"he"` | $W\sim N(0,\ 2/fan_{in})$ | ReLU | 保持各层方差稳定 |
| `"xavier"` | $W\sim N(0,\ 2/(fan_{in}+fan_{out}))$ | tanh / sigmoid | 同时考虑扇入扇出 |
| `"zeros"` | $W=0$ | 反面教材 | 隐藏层输出恒 0，网络学不动 |

`fan_in` 是这一层的输入个数，`fan_out` 是输出个数。以 `W1(784,128)` 为例：`fan_in=784`、`fan_out=128`。

### `seed`

随机种子，`int`。同一个 `seed` 得到同一组初始权重，方便复现实验。
`self.rng = np.random.default_rng(seed)` 创建随机数生成器，后面用
`self.rng.normal(0.0, std, size=(fan_in, fan_out))` 抽正态随机数。

### `self.Ws` 和 `self.bs`

这是最容易看不懂的两个名字。它们是**列表**，每个元素是一层的参数：

| 属性 | 类型 | 长度 | 第 i 个元素的形状 |
|---|---|---|---|
| `self.Ws` | `list[Array]` | 层数 | `self.Ws[i].shape == (fan_in_i, fan_out_i)` |
| `self.bs` | `list[Array]` | 层数 | `self.bs[i].shape == (fan_out_i,)` |

以 `MLP([784, 128, 10])` 为例：

| 表达式 | 值 |
|---|---|
| `self.layer_sizes` | `[784, 128, 10]` |
| `len(self.Ws)` | `2`（两层：784→128、128→10） |
| `self.Ws[0].shape` | `(784, 128)` |
| `self.bs[0].shape` | `(128,)` |
| `self.Ws[1].shape` | `(128, 10)` |
| `self.bs[1].shape` | `(10,)` |
| `len(self.bs)` | `2` |

为什么用列表？因为层数不固定：两层的网络 `len=2`，四层的网络 `len=4`，循环处理比写死 `W1, W2, W3` 更通用。

`Ws` 的 `s` 表示复数（多个矩阵），`bs` 同理；`self.Ws[0]` 才是单个矩阵。

### `forward` 的参数

```python
def forward(self, X: Array, cache: bool = False) -> Array | tuple[Array, ForwardCache]:
```

| 参数/返回值 | 类型 | 含义 |
|---|---|---|
| `X` | `Array` | 输入，`(N, D)` |
| `cache` | `bool` | 是否保存反向传播的中间量 |
| 返回（cache=False） | `Array` | logits，`(N, C)` |
| 返回（cache=True） | `tuple[Array, ForwardCache]` | `(logits, layers)` |

`cache=True` 时，`layers[i]` 是一个三元组：

| 名字 | 形状 | 含义 |
|---|---|---|
| `a_prev` | `(N, fan_in)` | 这一层的输入（上一层的输出，激活后） |
| `z` | `(N, fan_out)` | 仿射输出 `a_prev @ W + b`，**激活前** |
| `a` | `(N, fan_out)` | 这一层的输出；隐藏层是 `f(z)`，输出层就是 logits |

第 3 步反向传播需要 `a_prev` 算 `dW`，需要 `z` 算激活函数的导数，所以两样都要存。

### 其他名字

| 名字 | 类型 | 含义 |
|---|---|---|
| `self.rng` | `np.random.Generator` | 随机数生成器 |
| `self.activation` | `str` | 激活函数名 |
| `self.init` | `str` | 初始化方式 |
| `std` | `float` | 正态分布的标准差 |
| `n_layers` | `int` | `len(self.Ws)`，层数 |
| `a_next` | `Array` | 当前层的输出，下一层的输入 |
| `logits` | `Array` | 输出层打分，`(N, C)` |
| `count_parameters()` | `int` | 所有 W、b 元素个数之和 |

## 5. Python 小语法（读代码时卡住的地方）

### `self`

`self` 是"当前这个对象"。`self.Ws = []` 表示"给这个对象挂一个叫 Ws 的属性"。
同一个类可以创建多个对象，每个对象有自己的 `self.Ws`。

### `__init__`

构造函数。`MLP([784, 128, 10])` 会自动调用 `__init__`，把 `[784,128,10]` 传给 `layer_sizes`，并返回一个对象。

### `zip(a, b)`

把两个列表按位置配对：

```python
list(zip([784, 128], [128, 10]))   # [(784, 128), (128, 10)]
```

### 切片 `[:-1]` 和 `[1:]`

```python
xs = [784, 128, 10]
xs[:-1]   # [784, 128]   去掉最后一个
xs[1:]    # [128, 10]    去掉第一个
```

### `enumerate`

同时给出下标和元素：

```python
for i, (W, b) in enumerate(zip(self.Ws, self.bs)):
    ...
```

`i` 从 0 开始，`(W, b)` 是第 i 层的参数。

### `append`

往列表末尾加一个元素：

```python
self.Ws.append(W)   # 现在 Ws 多了一个矩阵
```

### 三元表达式

```python
a_next = f(z) if i < n_layers - 1 else z
```

读作：如果 `i` 不是最后一层，`a_next = f(z)`；否则 `a_next = z`。

### `if cache:`

`cache` 是 `bool`，`if cache:` 等价于 `if cache is True:`。

## 6. 常见类型/形状错误

| 现象 | 原因 |
|---|---|
| `IndexError: list index out of range` | `self.Ws[2]` 越界；两层网络只有下标 0、1 |
| `ValueError: shapes (N,D) and (H,D) not aligned` | W 的形状写反了，应该是 `(D,H)` |
| `TypeError: 'NoneType' object is not subscriptable` | 函数忘了 `return`，返回了 `None` |
| 准确率一直是 0.1 | 初始化全零，所有样本预测成同一类 |
| `sigmoid` 结果是整数 | 传入了整数数组，`np.empty_like` 沿用了整数 dtype |
| `loss` 是 `np.float64` 而不是 `float` | 用 `float(...)` 包一层；类型标注要求 Python `float` |

## 7. 自测：读下面几行，说出形状

```python
m = MLP([784, 256, 128, 10])
X = np.zeros((32, 784))
logits, layers = m.forward(X, cache=True)
```

1. `m.Ws[0].shape`、`m.Ws[1].shape`、`m.Ws[2].shape` 分别是什么？
2. `logits.shape` 是什么？
3. `layers` 有几个元素？`layers[1][2].shape` 是什么？
4. `m.count_parameters()` 是多少？

答案：

1. `(784,256)`、`(256,128)`、`(128,10)`。
2. `(32,10)`。
3. 3 个；`layers[1][2]` 是第 2 层的输出，形状 `(32,128)`。
4. $784\times256+256+256\times128+128+128\times10+10=235{,}146$。

---

**一句话总结**：

- `Ws`/`bs` 是"每层一个"的列表，下标是层号；
- `fan_in`/`fan_out` 是一层的输入/输出维，决定 `(fan_in, fan_out)`；
- `he`/`xavier`/`zeros` 是三种初始化策略，区别只在 `std`；
- `cache` 里的 `(a_prev, z, a)` 分别是"层输入、激活前、激活后"；
- 类型标注 `Array` 就是 `np.ndarray`，`-> tuple[...]` 描述返回值。
