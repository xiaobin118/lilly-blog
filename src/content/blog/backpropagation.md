---
title: "反向传播：从输出层误差到第一层梯度"
description: "从输出层的误差 dZ=(P-Y)/N 出发逐层回传，整理成矩阵运算并做数值梯度校验。"
date: 2026-10-19
tags: [deep-learning, backpropagation, numpy]
type: note
topic: "深度学习"
project: mlp
---

这一篇从输出层的误差出发，把梯度逐层传回第一层。重点是把形状对上、把矩阵写对，最后用数值梯度确认没有漏项。

## 1. 本步目标

从输出层的误差

$$
\delta^{(2)}=\frac{\partial L}{\partial Z_2}=\frac{1}{N}(P-Y)
$$

出发，把梯度一路传回第一层，得到 `dW1, db1, dW2, db2`，并用数值梯度验证。

完成后你应该能：

1. 对任意一层说出 `dW`、`db`、`dA_prev` 的形状，并解释为什么是那个形状；
2. 解释为什么激活函数的导数要用 **`z`（激活前）**，而不是 `a`（激活后）；
3. 看到梯度检查误差 $10^{-2}$ 时，知道大概是哪几类错误。

## 2. 计算图

前向：

```
X --(W1,b1)--> Z1 --relu--> H --(W2,b2)--> Z2 --softmax+CE--> loss
```

反向就是沿着箭头倒着走：

```
loss --dZ2--> dW2, db2, dH --relu'--> dZ1 --dW1, db1
```

链式法则一句话：**如果 $L$ 通过 $H$ 依赖 $Z_1$，那么 $\frac{\partial L}{\partial Z_1}=\frac{\partial L}{\partial H}\odot\frac{\partial H}{\partial Z_1}$。** 矩阵求导的所有公式都是这句话的具体展开。

## 3. 起点：输出层的误差

第 1 步已经推过：softmax + 交叉熵对 logits 的梯度是

$$
\delta^{(2)}=\frac{\partial L}{\partial Z_2}=\frac{1}{N}\left(P-Y\right),
$$

- $P$：softmax 概率，形状 $(N,C)$；
- $Y$：one-hot 标签，形状 $(N,C)$；
- 除以 $N$ 是因为损失对 $N$ 个样本取了平均。

这一步**不需要**再单独对 softmax 求导，它已经包含在 $(P-Y)$ 里了。

## 4. 线性层反向

考虑一层

$$
Z=A_{\text{prev}}W+b,
$$

形状：$A_{\text{prev}}(N,n_{\text{in}})$、$W(n_{\text{in}},n_{\text{out}})$、$b(n_{\text{out}},)$、$Z(N,n_{\text{out}})$。

已知 $\delta=\partial L/\partial Z$，形状 $(N,n_{\text{out}})$。用分量写开：

$$
Z_{n,j}=\sum_{i=1}^{n_{\text{in}}}A_{n,i}W_{i,j}+b_j.
$$

### 4.1 对 W 的梯度

$$
\frac{\partial L}{\partial W_{i,j}}=\sum_{n=1}^{N}\frac{\partial L}{\partial Z_{n,j}}\frac{\partial Z_{n,j}}{\partial W_{i,j}}=\sum_{n=1}^{N}\delta_{n,j}A_{n,i}.
$$

这正是矩阵乘法 $A^\top\delta$ 的第 $(i,j)$ 个元素，所以

$$
\boxed{\frac{\partial L}{\partial W}=A_{\text{prev}}^\top\delta}
$$

形状检查：$(n_{\text{in}},N)\times(N,n_{\text{out}})=(n_{\text{in}},n_{\text{out}})$，和 $W$ 一致。

### 4.2 对 b 的梯度

$$
\frac{\partial L}{\partial b_j}=\sum_{n=1}^{N}\delta_{n,j},
$$

即沿样本维求和：

$$
\boxed{\frac{\partial L}{\partial b}=\sum_{n=1}^{N}\delta_{n,:}}
$$

形状：$(n_{\text{out}},)$。代码里写成 `delta.sum(axis=0)`。

### 4.3 传给上一层的梯度

$$
\frac{\partial L}{\partial A_{n,i}}=\sum_{j=1}^{n_{\text{out}}}\delta_{n,j}W_{i,j},
$$

即

$$
\boxed{\frac{\partial L}{\partial A_{\text{prev}}}=\delta W^\top}
$$

形状：$(N,n_{\text{out}})\times(n_{\text{out}},n_{\text{in}})=(N,n_{\text{in}})$，和 $A_{\text{prev}}$ 一致。

### 4.4 形状表

| 量 | 形状 | 公式 |
|---|---|---|
| `dZ` | `(N, n_out)` | 已知 |
| `dW` | `(n_in, n_out)` | `a_prev.T @ dZ` |
| `db` | `(n_out,)` | `dZ.sum(axis=0)` |
| `dA_prev` | `(N, n_in)` | `dZ @ W.T` |

**转置是最常见的错误。** 记不住时就写形状：`a_prev.T @ dZ` 是 `(n_in,N)@(N,n_out)`，结果 `(n_in,n_out)` 正好是 `W`；写成 `dZ.T @ a_prev` 会得到 `(n_out,n_in)`，和 `W` 对不上。

## 5. 激活层反向

激活函数逐元素作用：

$$
H_{n,j}=f(Z_{n,j}).
$$

所以 $H$ 只通过第 $j$ 个元素依赖 $Z_{n,j}$，链式法则变成逐元素相乘：

$$
\boxed{\delta_{\text{prev}}=\frac{\partial L}{\partial A_{\text{prev}}}=\delta\odot f'(Z_{\text{prev}})}
$$

其中 $Z_{\text{prev}}$ 是**激活前**的值。

三个导数：

| 激活 | $f(z)$ | $f'(z)$ | 代码 |
|---|---|---|---|
| ReLU | $\max(0,z)$ | $1$ if $z>0$ else $0$ | `(z > 0).astype(float)` |
| sigmoid | $\frac{1}{1+e^{-z}}$ | $f(z)(1-f(z))$ | `s * (1 - s)` |
| tanh | $\tanh z$ | $1-\tanh^2 z$ | `1 - np.tanh(z)**2` |
| linear | $z$ | $1$ | `np.ones_like(z)` |

**为什么必须用 $z$ 而不是 $a$？** 对 sigmoid/tanh，$f'(z)$ 可以用输出 $a=f(z)$ 表示，看起来 $a$ 也够；但 ReLU 的导数在 $z<0$ 和 $z>0$ 都是常数，只有知道 $z$ 的符号才能判断，而 $a=0$ 既可能来自 $z<0$，也可能来自 $z=0$。所以缓存里必须存 `z`。这也是第 2 步让你存 `(a_prev, z, a)` 的原因。

## 6. 完整的反向算法

设网络有 $L$ 层（不含输入层），`layers[l] = (a_prev, z, a)`。

```python
logits, layers = model.forward(X, cache=True)
loss, dZ = cross_entropy(logits, y)        # dZ = (P - Y) / N，形状 (N, C)

dWs, dbs = [None] * L, [None] * L
for l in range(L - 1, -1, -1):             # 从最后一层往前
    a_prev, z, a = layers[l]
    W = model.Ws[l]

    dWs[l] = a_prev.T @ dZ                 # (n_in, n_out)
    dbs[l] = dZ.sum(axis=0)                # (n_out,)

    if l > 0:
        dA_prev = dZ @ W.T                 # (N, n_in)
        dZ = dA_prev * f_prime(layers[l - 1][1])   # 用上一层的 z
```

注意循环里算 `dZ` 时用的是 `layers[l - 1][1]`，也就是**上一层的 `z`**：`dA_prev` 是"损失对上一层激活输出的梯度"，还要再穿过上一层的激活函数，才变成"损失对上一层仿射输出的梯度"。

以 `[N,3] -> 5 -> 4` 为例：

| 步骤 | dZ 形状 | 计算 |
|---|---|---|
| 输出层 l=1 | `(N,4)` | `(P-Y)/N` |
| dW2 | `(5,4)` | `H.T @ dZ` |
| db2 | `(4,)` | `dZ.sum(0)` |
| dA1 | `(N,5)` | `dZ @ W2.T` |
| dZ1 | `(N,5)` | `dA1 * relu'(Z1)` |
| dW1 | `(3,5)` | `X.T @ dZ1` |
| db1 | `(5,)` | `dZ1.sum(0)` |

## 7. L2 正则

损失加上

$$
L_{\text{reg}}=\frac{\lambda}{2}\sum_l\lVert W_l\rVert_F^2,
$$

梯度相应多一项：

$$
\frac{\partial L}{\partial W_l}\leftarrow\frac{\partial L}{\partial W_l}+\lambda W_l.
$$

偏置不参与正则。注意**损失和梯度要同时加**：只在损失里加会让数值梯度比解析梯度多出 $\lambda W$，只在梯度里加会让损失与梯度不一致。

## 8. 数值梯度检查

反向传播写错时程序不会崩，只会"训练效果莫名很差"。所以必须用数值梯度当标准答案：

$$
\frac{\partial L}{\partial\theta_i}\approx\frac{L(\theta_i+\epsilon)-L(\theta_i-\epsilon)}{2\epsilon}.
$$

`common.finite_difference_error` 会随机抽查每个参数数组里的元素，施加 $\pm\epsilon$ 的扰动，再和你的解析梯度比较，返回最大绝对误差。

判断标准：

| 最大误差 | 含义 |
|---|---|
| $<10^{-6}$ | 正确（float64 + 中心差分的正常水平） |
| $10^{-4}\sim10^{-3}$ | 某处差一个小因子，或 L2 只加了一边 |
| $10^{-2}$ 以上 | 公式错了：转置、漏乘激活导数、dZ 起点错、忘记 /N |
| `nan` | 损失里有 `log(0)` 或除零 |

ReLU 在 $z=0$ 处不可导。如果某个 $z$ 恰好落在 $\pm\epsilon$ 内，数值梯度会和解析梯度有 $O(1)$ 的差。概率很低，换个种子即可；不要为了让检查通过而把 ReLU 改成别的。

## 9. 实现任务

打开 `practice/step03_backward.py`。这个文件继承第 2 步的 `MLP`，只需要加两个东西。

> 关于 `class MLP(ForwardMLP)`：括号里是父类。子类自动拥有父类的
> `__init__`、`forward`、`predict`、`count_parameters`；我们只新增
> `loss_and_grads`。调用 `MLP([3,5,4])` 时执行的是父类的 `__init__`，
> 所以 `self.Ws`、`self.bs`、`self.forward` 都能直接用。

### TODO 1：激活函数的导数

实现三个函数：

```python
def relu_grad(z: Array) -> Array:      # z > 0 处为 1，否则 0
def sigmoid_grad(z: Array) -> Array:   # s * (1 - s)，s = sigmoid(z)
def tanh_grad(z: Array) -> Array:      # 1 - tanh(z)**2
```

`linear_grad` 已提供。要求返回 `float` 数组，形状与 `z` 相同。

### TODO 2：`MLP.loss_and_grads`

```python
def loss_and_grads(
    self, X: Array, y: Array, l2: float = 0.0
) -> tuple[float, list[Array]]:
```

返回 `(loss, grads)`，其中 `grads` 的顺序必须是 **先所有 `dW`，再所有 `db`**，和 `self.Ws + self.bs` 一一对应。这样数值梯度检查可以直接按位置比较。

步骤：

1. `logits, layers = self.forward(X, cache=True)`；
2. `loss, dZ = cross_entropy(logits, y)`（从第 1 步直接 import）；
3. 从最后一层往前循环，按第 6 节的伪代码算 `dW`、`db`、`dZ`；
4. 有 `l2` 时，损失加 $\frac{\lambda}{2}\sum\lVert W\rVert^2$，每个 `dW` 加 $\lambda W$；
5. 返回 `loss, dWs + dbs`。

## 10. 自检说明

运行 `python step03_backward.py`，七项检查：

| 检查 | 验证什么 |
|---|---|
| 1. 激活导数 | ReLU 截断、sigmoid 在 0 处 0.25、tanh 在 0 处 1 |
| 2. ReLU 梯度 | 三层网络的解析梯度 vs 数值梯度 |
| 3. tanh 梯度 | 同上 |
| 4. sigmoid 梯度 | 同上 |
| 5. L2 梯度 | $\lambda=0.01$ 时损失和梯度是否一致 |
| 6. 梯度形状 | 4 个数组，形状与 `Ws + bs` 一致 |
| 7. 损失下降 | 用你算的梯度做 30 步全批量更新，损失应下降 |

## 11. 常见错误

1. **`dW = dZ.T @ a_prev`**：形状是 `(n_out, n_in)`，与 `W` 不符。先写形状再写代码。
2. **`dA_prev = dZ @ W`**：少了转置，`(N,n_out)@(n_in,n_out)` 直接报错；应是 `W.T`。
3. **忘记乘激活导数**：`dZ` 直接传到上一层，梯度检查会在 $10^{-2}$ 量级。
4. **用 `layers[l][1]` 而不是 `layers[l-1][1]`**：激活导数的下标错了一位。
5. **输出层也乘激活导数**：输出层没有激活，乘了会多一个因子。
6. **`dZ` 起点写成 `(P - Y)`**：忘记除以 $N$，梯度大 $N$ 倍，学习率看起来"太大"。
7. **交叉熵里原地修改了 `P`**：`dlogits = P` 再 `-= 1` 会把 `P` 破坏，损失和梯度不一致；要先 `P.copy()`。
8. **L2 只加在损失或只加在梯度**：检查 5 会失败。
9. **返回顺序和 `Ws + bs` 不一致**：检查 6 比较时会错位。

## 12. 思考题

1. 如果网络有两个隐藏层，`dZ` 在循环里会被覆盖几次？每次覆盖前，`dW_l` 是否已经算完？
2. 为什么 `dA_prev = dZ @ W.T` 里的转置在右边，而 `dW = a_prev.T @ dZ` 的转置在左边？从形状和"谁对谁求和"两个角度各解释一次。
3. 如果把 ReLU 的导数在 $z=0$ 处取 1 而不是 0，对训练有什么影响？为什么实践中无所谓？

## 13. 小结与下一步

本步完成后，你已经拥有一个可以训练的 MLP：前向、损失、反向全齐。第 4 步把它接到小批量训练循环上，实现 SGD / Momentum / Adam，在 MNIST 子集上跑到 95% 以上。

---

**完成后发回**：

1. `python step03_backward.py` 的完整输出（七项 PASS/FAIL，以及四种配置的梯度误差）；
2. 你写的 `loss_and_grads` 循环；
3. 一句话：`dA_prev` 和 `dZ` 的先后关系，你是怎么记住的。
