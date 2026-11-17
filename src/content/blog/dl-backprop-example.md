---
title: "第 3 步例题：三层网络的反向传播全过程"
description: "注意 的第 2 行第 2 列恰好是 0。这是后面第 5 节要讨论的 ReLU 拐点。"
date: 2026-10-19
tags: [deep-learning, backprop]
type: note
topic: "深度学习"
---

> 用一个所有数字都能手算的小网络，把反向传播的每一次矩阵乘法、每一次 `dZ` 覆盖都写出来。
>
> 网络：2 维输入 → 2 个隐藏单元 → 2 个隐藏单元 → 2 类。
> 两个隐藏层都用 ReLU，输出层线性 + softmax 交叉熵。样本数 $N=2$。

## 1. 网络与数据

$$
X=\begin{bmatrix}1&0\\0&1\end{bmatrix},\qquad
y=[0,1],\qquad
W_1=\begin{bmatrix}1&-1\\1&1\end{bmatrix},\quad b_1=0,
$$

$$
W_2=\begin{bmatrix}1&1\\1&-1\end{bmatrix},\quad b_2=0,\qquad
W_3=\begin{bmatrix}1&0\\0&1\end{bmatrix},\quad b_3=0.
$$

$X$ 是单位矩阵，所以下面很多地方可以直接读出结果；$W_3$ 是单位矩阵，输出层不改变 $H_2$。

## 2. 前向传播

### 第 1 层

$$
Z_1=XW_1+b_1=\begin{bmatrix}1&-1\\1&1\end{bmatrix},
\qquad
H_1=\mathrm{ReLU}(Z_1)=\begin{bmatrix}1&0\\1&1\end{bmatrix}.
$$

### 第 2 层

$$
Z_2=H_1W_2+b_2=\begin{bmatrix}1&1\\2&0\end{bmatrix},
\qquad
H_2=\mathrm{ReLU}(Z_2)=\begin{bmatrix}1&1\\2&0\end{bmatrix}.
$$

注意 $Z_2$ 的第 2 行第 2 列**恰好是 0**。这是后面第 5 节要讨论的 ReLU 拐点。

### 输出层

$$
Z_3=H_2W_3+b_3=\begin{bmatrix}1&1\\2&0\end{bmatrix}.
$$

softmax：

- 第 1 个样本：$\mathrm{softmax}([1,1])=[0.5,0.5]$；
- 第 2 个样本：$\mathrm{softmax}([2,0])=[0.8808,0.1192]$。

$$
P=\begin{bmatrix}0.5&0.5\\0.8808&0.1192\end{bmatrix}.
$$

损失（$y=[0,1]$）：

$$
L=\frac{1}{2}\left[-\log 0.5-\log 0.1192\right]=1.4100.
$$

## 3. 反向传播的起点

$$
dZ_3=\frac{1}{N}(P-Y)=\frac{1}{2}\begin{bmatrix}0.5-1&0.5-0\\0.8808-0&0.1192-1\end{bmatrix}
=\begin{bmatrix}-0.25&0.25\\0.4404&-0.4404\end{bmatrix}.
$$

## 4. 逐层反向

### 4.1 输出层 $l=2$

$H_2=\begin{bmatrix}1&1\\2&0\end{bmatrix}$。

$$
dW_3=H_2^\top dZ_3
=\begin{bmatrix}1&2\\1&0\end{bmatrix}
\begin{bmatrix}-0.25&0.25\\0.4404&-0.4404\end{bmatrix}
=\begin{bmatrix}0.6308&-0.6308\\-0.25&0.25\end{bmatrix},
$$

$$
db_3=\sum_n dZ_{3,n,:}=[0.1904,\ -0.1904].
$$

传给上一层：

$$
dA_2=dZ_3W_3^\top=dZ_3=\begin{bmatrix}-0.25&0.25\\0.4404&-0.4404\end{bmatrix}.
$$

### 4.2 第 2 个隐藏层 $l=1$

激活导数（$Z_2=\begin{bmatrix}1&1\\2&0\end{bmatrix}$）：

$$
\mathrm{ReLU}'(Z_2)=\begin{bmatrix}1&1\\1&0\end{bmatrix}.
$$

逐元素相乘：

$$
dZ_2=dA_2\odot\mathrm{ReLU}'(Z_2)
=\begin{bmatrix}-0.25&0.25\\0.4404&0\end{bmatrix}.
$$

$$
dW_2=H_1^\top dZ_2
=\begin{bmatrix}1&1\\0&1\end{bmatrix}
\begin{bmatrix}-0.25&0.25\\0.4404&0\end{bmatrix}
=\begin{bmatrix}0.1904&0.25\\0.4404&0\end{bmatrix},
$$

$$
db_2=[0.1904,\ 0.25].
$$

传给上一层：

$$
dA_1=dZ_2W_2^\top
=\begin{bmatrix}-0.25&0.25\\0.4404&0\end{bmatrix}
\begin{bmatrix}1&1\\1&-1\end{bmatrix}
=\begin{bmatrix}0&-0.5\\0.4404&0.4404\end{bmatrix}.
$$

### 4.3 第 1 个隐藏层 $l=0$

$Z_1=\begin{bmatrix}1&-1\\1&1\end{bmatrix}$，所以

$$
\mathrm{ReLU}'(Z_1)=\begin{bmatrix}1&0\\1&1\end{bmatrix},
\qquad
dZ_1=dA_1\odot\mathrm{ReLU}'(Z_1)=\begin{bmatrix}0&0\\0.4404&0.4404\end{bmatrix}.
$$

$$
dW_1=X^\top dZ_1
=\begin{bmatrix}1&0\\0&1\end{bmatrix}
\begin{bmatrix}0&0\\0.4404&0.4404\end{bmatrix}
=\begin{bmatrix}0&0\\0.4404&0.4404\end{bmatrix},
$$

$$
db_1=[0.4404,\ 0.4404].
$$

### 4.4 数值验证

对 $W_1[0,0]$、$W_2[0,0]$、$W_3[0,0]$ 做中心差分，得到：

| 参数 | 解析梯度 | 数值梯度 |
|---|---|---|
| $W_3[0,0]$ | 0.6308 | 0.6308 |
| $W_2[0,0]$ | 0.1904 | 0.1904 |
| $W_1[0,0]$ | 0.0000 | 0.0000 |

三者一致。$W_1[0,0]$ 的梯度为 0，可以这样看：$X$ 的第 0 列只有第一个样本非零，而 $dZ_1$ 的第一行恰好是 $[0,0]$——第一个样本的第二个隐藏单元被 ReLU 关掉（$Z_1[0,1]=-1$，导数为 0），第一个隐藏单元虽然激活，但它对应的 $dA_1[0,0]$ 本身就是 0。

## 5. 问题 1：`dZ` 在循环里被覆盖几次？

两个隐藏层 + 一个输出层，共 3 个权重矩阵。循环从 $l=2$ 到 $l=0$：

| 迭代 | 进入循环时的 `dZ` | 先算什么 | 离开时的 `dZ` | 是否覆盖 |
|---|---|---|---|---|
| $l=2$ | $dZ_3$ | $dW_3,db_3$ | $dZ_2$ | 第 1 次 |
| $l=1$ | $dZ_2$ | $dW_2,db_2$ | $dZ_1$ | 第 2 次 |
| $l=0$ | $dZ_1$ | $dW_1,db_1$ | 不变（`l > 0` 不成立） | 不覆盖 |

所以：

- `dZ` 被**赋值 3 次**（`dZ3` 初始化一次，之后覆盖 2 次）；
- 说"覆盖"是 **2 次**，等于"权重层数 − 1"；
- **每次覆盖前，当前层的 `dW_l` 和 `db_l` 都已经算完**。代码的顺序是：

```python
dWs[l] = a_prev.T @ dZ     # 先用当前 dZ
dbs[l] = dZ.sum(axis=0)    # 先用当前 dZ
if l > 0:
    dA_prev = dZ @ W.T
    dZ = dA_prev * grad_fn(...)   # 这里才覆盖
```

如果反过来，先写 `dZ = dA_prev * grad_fn(...)`，再算 `dW_l`，那么 `dW_l` 用的就是**上一层的** `dZ`，形状可能刚好能乘（或者报错），但数值全错。记忆方法：**先消费，再生产**。

## 6. 问题 2：两个转置为什么一左一右？

### 6.1 从"谁对谁求和"看

前向公式（分量形式）：

$$
Z_{n,j}=\sum_{i=1}^{n_{\text{in}}}A_{n,i}W_{i,j}+b_j.
$$

**对 $W$ 求导**：$W_{i,j}$ 只影响 $Z_{n,j}$（所有样本的同一个输出单元），所以

$$
dW_{i,j}=\sum_{n=1}^{N}A_{n,i}\,dZ_{n,j}.
$$

这里对 **样本 $n$** 求和。$A$ 的 $n$ 是行，$dZ$ 的 $n$ 也是行；要让 $n$ 成为矩阵乘法的"内维"，把 $A$ 转置：

$$
(A^\top)_{i,n}(dZ)_{n,j}\;\Longrightarrow\;dW=A^\top dZ.
$$

用本例验证 $dW_3[0,0]$：

$$
dW_3[0,0]=\sum_{n=1}^{2}H_{2}[n,0]\,dZ_3[n,0]
=1\times(-0.25)+2\times0.4404=0.6308.
$$

**对 $A$ 求导**：$A_{n,i}$ 通过所有权重 $W_{i,j}$ 影响所有输出 $Z_{n,j}$，所以

$$
dA_{n,i}=\sum_{j=1}^{n_{\text{out}}}dZ_{n,j}\,W_{i,j}.
$$

这里对 **输出单元 $j$** 求和。$dZ$ 的 $j$ 是列，$W$ 的 $j$ 是行；要让 $j$ 成为内维，把 $W$ 转置：

$$
(dZ)_{n,j}(W^\top)_{j,i}\;\Longrightarrow\;dA=dZ\,W^\top.
$$

用本例验证 $dA_2[1,0]$：

$$
dA_2[1,0]=\sum_{j=1}^{2}dZ_3[1,j]\,W_3[0,j]
=0.4404\times1+(-0.4404)\times0=0.4404.
$$

### 6.2 从形状看

- $dW$ 必须和 $W$ 同形状 $(n_{\text{in}},n_{\text{out}})$。$A^\top$ 是 $(n_{\text{in}},N)$，$dZ$ 是 $(N,n_{\text{out}})$，乘出来正好；反过来 $dZ^\top A$ 是 $(n_{\text{out}},n_{\text{in}})$，和 $W$ 对不上。
- $dA$ 必须和 $A$ 同形状 $(N,n_{\text{in}})$。$dZ$ 是 $(N,n_{\text{out}})$，$W^\top$ 是 $(n_{\text{out}},n_{\text{in}})$，乘出来正好；$dZ\,W$ 是 $(N,n_{\text{out}})(n_{\text{in}},n_{\text{out}})$，除非 $n_{\text{in}}=n_{\text{out}}$，否则直接报错。

一句话：**被求和的维度要放到中间**。求 $W$ 的梯度时对样本求和，所以 $A$ 转置到左边；求 $A$ 的梯度时对输出单元求和，所以 $W$ 转置到右边。

## 7. 问题 3：ReLU 在 0 处取 0 还是 1？

### 7.1 这不是"对错"，是选哪个次梯度

ReLU 在 $z=0$ 处左右导数不相等（左边 0、右边 1），严格说不可导。凸分析里可以取 $[0,1]$ 内任意值作为**次梯度**，0 和 1 都是合法选择。

- `(z > 0)`：$z=0$ 取 0（PyTorch、TensorFlow 的常见实现）；
- `(z >= 0)`：$z=0$ 取 1。

### 7.2 在本例中具体差在哪

$Z_2$ 的第 2 行第 2 列恰好是 0。如果取 1，`dZ2` 会变成

$$
dZ_{2}^{\text{alt}}=\begin{bmatrix}-0.25&0.25\\0.4404&-0.4404\end{bmatrix},
$$

而不是原来的

$$
dZ_2=\begin{bmatrix}-0.25&0.25\\0.4404&0\end{bmatrix}.
$$

差异从这一个元素往下传：

| 量 | 取 0（原方案） | 取 1（alt） |
|---|---|---|
| $dW_2$ | $\begin{bmatrix}0.1904&0.25\\0.4404&0\end{bmatrix}$ | $\begin{bmatrix}0.1904&-0.1904\\0.4404&-0.4404\end{bmatrix}$ |
| $db_2$ | $[0.1904,0.25]$ | $[0.1904,-0.1904]$ |
| $dA_1$ | $\begin{bmatrix}0&-0.5\\0.4404&0.4404\end{bmatrix}$ | $\begin{bmatrix}0&-0.5\\0&0.8808\end{bmatrix}$ |
| $dZ_1$ | $\begin{bmatrix}0&0\\0.4404&0.4404\end{bmatrix}$ | $\begin{bmatrix}0&0\\0&0.8808\end{bmatrix}$ |
| $dW_1$ | $\begin{bmatrix}0&0\\0.4404&0.4404\end{bmatrix}$ | $\begin{bmatrix}0&0\\0&0.8808\end{bmatrix}$ |
| $db_1$ | $[0.4404,0.4404]$ | $[0,0.8808]$ |

可以清楚看到：差异只沿着"那个恰好落在 0 的单元"的路径传播，其他位置完全一样。

### 7.3 为什么实践中无所谓

1. **精确落在 0 的概率是 0。** $z$ 是连续随机变量的函数，恰好等于 0 是零测事件。本例的 0 是我们为了好算，故意让 $H_1=[1,1]$、$W_2$ 的第二列 $=[1,-1]$ 构造出来的。
2. **即使发生，也只影响个别坐标。** 上面的表里只有与那个单元相关的几项变化，不会改变整个网络的行为。
3. **两种选择都是合法的次梯度。** 从优化的角度，0 和 1 都在次微分区间 $[0,1]$ 内；随机梯度下降对这类零测集上的选择不敏感。
4. **真正的问题不是拐点，而是"死亡 ReLU"。** 如果某个单元对所有样本都有 $z<0$，它的导数恒为 0，参数永远不更新。这是 $z<0$ 的区域，和 $z=0$ 那一个点无关；解决办法是换 Leaky ReLU、调小学习率或换初始化，而不是纠结 0 处取 0 还是 1。
5. **框架之间的差异也说明它不重要。** PyTorch、TensorFlow、JAX 在这一点上的约定不完全相同，但训练结果没有实质差别。

结论：写 `(z > 0)` 或 `(z >= 0)` 都行；本课程用 `(z > 0)`，与主流框架保持一致。真正要保证的是**负区间导数为 0、正区间导数为 1**。
