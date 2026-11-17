---
title: "用一个例子从头计算反向传播"
description: "手算一个 $2\to2\to1$ 的神经网络的前向、反向传播与梯度，理解链式法则、误差项、矩阵形式与批量。"
date: 2026-10-19
tags: [deep-learning, backpropagation, numpy]
type: note
topic: "深度学习"
project: mlp
---
## 1 热身：一个标量的链式法则

先不看网络。设

$$
z=2w+1,\qquad a=\sigma(z),\qquad L=(a-1)^2,
$$

取 $w=0$。前向：$z=2\times0+1=1$，$a=1/(1+e^{-1})=0.731059$，$L=(0.731059-1)^2=0.0723295$。

问 $\partial L/\partial w$。按链式法则，一条链：$w\to z\to a\to L$，把每段的局部导数乘起来。

第一段（$L$ 对 $a$）：

$$
\frac{\partial L}{\partial a}=2(a-1)=2\times(0.731059-1)=-0.537883 .
$$

第二段（$a$ 对 $z$）：sigmoid 的导数 $\sigma'(z)=\sigma(z)(1-\sigma(z))$：

$$
\frac{\partial a}{\partial z}=0.731059\times(1-0.731059)=0.196612 .
$$

第三段（$z$ 对 $w$）：$z=2w+1$ 的斜率是 2。

连乘：

$$
\frac{\partial L}{\partial w}=(-0.537883)\times0.196612\times2=-0.211508 .
$$

**验证.** 用中心差分：$L(10^{-6})=0.07232928$、$L(-10^{-6})=0.07232970$，

$$
\frac{L(+\epsilon)-L(-\epsilon)}{2\epsilon}=\frac{-4.23\times10^{-7}}{2\times10^{-6}}=-0.211508 .
$$

与链式法则完全一致。

**记住这个模式**：一条路径 = 局部导数连乘。神经网络里唯一的复杂化是"多条路径要相加"。

## 2 网络、符号与形状

网络 $2\to2\to1$：

$$
z_1=W_1x+b_1,\quad a_1=\sigma(z_1),\quad z_2=W_2a_1+b_2,\quad \hat y=\sigma(z_2),
$$

$$
L=\frac12(\hat y-y)^2 .
$$

参数：$W_1=\begin{pmatrix}0.2&-0.4\\0.3&0.1\end{pmatrix}$、$b_1=(0.1,-0.2)$、$W_2=(0.5,-0.8)$、$b_2=0.2$；输入 $x=(1,0.5)$、目标 $y=1$。

**形状表**（这张表是理解转置的关键）：

| 量 | 形状 | 说明 |
|---|---|---|
| $x$ | $2\times1$ | 输入 |
| $W_1$ | $2\times2$ | 行 = 隐单元，列 = 输入 |
| $z_1,a_1$ | $2\times1$ | 每个隐单元一个数 |
| $W_2$ | $1\times2$ | 行 = 输出单元（这里 1 个），列 = 隐单元 |
| $z_2,\hat y$ | $1\times1$（标量） | 输出 |
| $\delta_2$ | $1\times1$ | 输出层误差项 |
| $\delta_1$ | $2\times1$ | 与 $z_1$ 同形 |

定义**误差项**：$\delta_l=\dfrac{\partial L}{\partial z_l}$。它是"损失对未激活输出的导数"，不是梯度本身。

## 3 前向：每个数

**第一层.**

$$
z_{1,1}=0.2\times1+(-0.4)\times0.5+0.1=0.2-0.2+0.1=0.100,
$$

$$
z_{1,2}=0.3\times1+0.1\times0.5-0.2=0.3+0.05-0.2=0.150 .
$$

激活：

$$
a_{1,1}=\sigma(0.1)=0.524979,\qquad a_{1,2}=\sigma(0.15)=0.537430 .
$$

**把导数也存下来**（反向要用）：

$$
\sigma'(z_{1,1})=a_{1,1}(1-a_{1,1})=0.524979\times0.475021=0.249376,
$$

$$
\sigma'(z_{1,2})=0.537430\times0.462570=0.248599 .
$$

**第二层.**

$$
z_2=0.5\times0.524979+(-0.8)\times0.537430+0.2
=0.262490-0.429944+0.2=0.032546 .
$$

$$
\hat y=\sigma(0.032546)=0.508136 .
$$

**损失.**

$$
L=\frac12(0.508136-1)^2=\frac12\times0.241930=0.120965 .
$$

## 4 输出层：δ2 的推导

$\delta_2=\partial L/\partial z_2$，链式法则：$L\leftarrow\hat y\leftarrow z_2$。

**第一段**：$L=\frac12(\hat y-y)^2$，对 $\hat y$ 求导

$$
\frac{\partial L}{\partial \hat y}=\hat y-y=0.508136-1=-0.491864 .
$$

**第二段**：$\hat y=\sigma(z_2)$，

$$
\frac{\partial \hat y}{\partial z_2}=\sigma'(z_2)=\hat y(1-\hat y)=0.508136\times0.491864=0.249934 .
$$

**连乘**：

$$
\delta_2=\frac{\partial L}{\partial \hat y}\cdot\frac{\partial \hat y}{\partial z_2}
=(-0.491864)\times0.249934=-0.122934 .
$$

**注意符号**：$\hat y<y$，所以 $\partial L/\partial\hat y<0$；$\delta_2<0$ 表示"增大 $z_2$ 会减小损失"。

**交叉熵的简化**：若损失是交叉熵、输出是 softmax/sigmoid，则 $\delta_2=\hat y-y$，那个 $\sigma'$ 与分母抵消。本题是平方误差，所以两个因子都要乘。

## 5 隐层：δ1 的推导（重点）

这里是最容易卡住的地方。目标是 $\delta_{1,j}=\partial L/\partial z_{1,j}$。路径是

$$
L\leftarrow z_2\leftarrow a_{1,j}\leftarrow z_{1,j}.
$$

**第一步：损失对隐层输出 $a_{1,j}$ 的导数.**

$z_2$ 依赖所有隐单元：

$$
z_2=W_{2,1}a_{1,1}+W_{2,2}a_{1,2}+b_2 .
$$

所以对 $a_{1,1}$ 求导，只有第一项含它：

$$
\frac{\partial L}{\partial a_{1,1}}
=\frac{\partial L}{\partial z_2}\cdot\frac{\partial z_2}{\partial a_{1,1}}
=\delta_2\cdot W_{2,1}
=(-0.122934)\times0.5=-0.061467 .
$$

同理

$$
\frac{\partial L}{\partial a_{1,2}}=\delta_2\cdot W_{2,2}=(-0.122934)\times(-0.8)=0.098347 .
$$

**第二步：再乘激活函数的导数.**

$$
\delta_{1,1}=\frac{\partial L}{\partial a_{1,1}}\cdot\sigma'(z_{1,1})
=(-0.061467)\times0.249376=-0.015328,
$$

$$
\delta_{1,2}=0.098347\times0.248599=0.024449 .
$$

**第三步：写成矩阵形式.**

$$
\delta_1=(W_2^{\mathsf T}\delta_2)\odot\sigma'(z_1),
$$

其中 $\odot$ 是逐元素乘。代入：

$$
W_2^{\mathsf T}\delta_2=\binom{0.5}{-0.8}\times(-0.122934)
=\binom{-0.061467}{0.098347},
$$

$$
\delta_1=\binom{-0.061467}{0.098347}\odot\binom{0.249376}{0.248599}
=\binom{-0.015328}{0.024449}.
$$

**为什么是 $W_2^{\mathsf T}$？** 看形状：$W_2$ 是 $1\times2$（输出 1 个、隐单元 2 个），$\delta_2$ 是 $1\times1$。要得到与 $z_1$ 同形的 $2\times1$，必须用 $W_2^{\mathsf T}$（$2\times1$）去乘。逐元素看：

$$
(W_2^{\mathsf T}\delta_2)_j=\sum_k W_{2,kj}\,\delta_{2,k}.
$$

含义是：**输出层的每个误差，按权重 $W_{2,kj}$ 分摊给隐单元 $j$**。权重大的连接分到的误差多。

如果输出层有多个神经元（$c$ 个），这个求和就真的要对 $k$ 求和，$W_2$ 是 $c\times h$，$\delta_2$ 是 $c\times1$，转置后 $h\times c$，乘出来 $h\times1$，形状对得上。

## 6 参数梯度：9 个参数全列出来

参数梯度公式：**误差项 × 该参数的输入**。

**$W_2$ 的两个元素**（输入是 $a_1$）：

$$
\frac{\partial L}{\partial W_{2,1}}=\delta_2\,a_{1,1}=(-0.122934)\times0.524979=-0.064538,
$$

$$
\frac{\partial L}{\partial W_{2,2}}=\delta_2\,a_{1,2}=(-0.122934)\times0.537430=-0.066068 .
$$

**$b_2$**（输入是 1）：

$$
\frac{\partial L}{\partial b_2}=\delta_2=-0.122934 .
$$

**$W_1$ 的四个元素**（输入是 $x$）：

$$
\frac{\partial L}{\partial W_{1,11}}=\delta_{1,1}x_1=(-0.015328)\times1=-0.015328,
$$

$$
\frac{\partial L}{\partial W_{1,12}}=\delta_{1,1}x_2=(-0.015328)\times0.5=-0.007664,
$$

$$
\frac{\partial L}{\partial W_{1,21}}=\delta_{1,2}x_1=0.024449\times1=0.024449,
$$

$$
\frac{\partial L}{\partial W_{1,22}}=\delta_{1,2}x_2=0.024449\times0.5=0.012224 .
$$

**$b_1$**：

$$
\frac{\partial L}{\partial b_1}=(\delta_{1,1},\delta_{1,2})=(-0.015328,0.024449).
$$

汇总成表：

| 参数 | 梯度 | 参数 | 梯度 |
|---|---|---|---|
| $W_{1,11}$ | $-0.015328$ | $W_{1,12}$ | $-0.007664$ |
| $W_{1,21}$ | $0.024449$ | $W_{1,22}$ | $0.012224$ |
| $b_{1,1}$ | $-0.015328$ | $b_{1,2}$ | $0.024449$ |
| $W_{2,1}$ | $-0.064538$ | $W_{2,2}$ | $-0.066068$ |
| $b_2$ | $-0.122934$ | | |

矩阵形式：

$$
\frac{\partial L}{\partial W_1}=\delta_1x^{\mathsf T}
=\binom{-0.015328}{0.024449}(1,\ 0.5)
=\begin{pmatrix}-0.015328&-0.007664\\0.024449&0.012224\end{pmatrix},
$$

$$
\frac{\partial L}{\partial W_2}=\delta_2a_1^{\mathsf T}
=(-0.122934)(0.524979,\ 0.537430)=(-0.064538,\ -0.066068).
$$

**规律**：$W$ 的梯度永远是"本层 $\delta$ × 本层输入"的外积。形状对得上：$\delta_1$ 是 $2\times1$、$x^{\mathsf T}$ 是 $1\times2$，外积 $2\times2$，正好是 $W_1$ 的形状。

## 7 路径视角：连乘与求和

**单条路径 = 连乘.** 以 $W_{1,11}$ 为例，它只影响 $z_{1,1}$，进而经 $a_{1,1}$、$z_2$ 影响 $L$，只有一条路径：

$$
\frac{\partial L}{\partial W_{1,11}}
=\underbrace{\frac{\partial L}{\partial\hat y}}_{-0.491864}
\cdot\underbrace{\frac{\partial\hat y}{\partial z_2}}_{0.249934}
\cdot\underbrace{\frac{\partial z_2}{\partial a_{1,1}}}_{0.5}
\cdot\underbrace{\frac{\partial a_{1,1}}{\partial z_{1,1}}}_{0.249376}
\cdot\underbrace{\frac{\partial z_{1,1}}{\partial W_{1,11}}}_{x_1=1}
=-0.015328 .
$$

连乘的顺序就是反向传播走的方向：把前两个因子合成 $\delta_2$，第三个因子进入 $W_2^{\mathsf T}$，第四个是 $\sigma'$，最后乘输入。

**多条路径 = 求和.** 输入 $x_1$ 同时影响两个隐单元，两条路径都要算：

路径一（经隐单元 1）：

$$
\delta_2\cdot W_{2,1}\cdot\sigma'(z_{1,1})\cdot W_{1,11}
=(-0.122934)\times0.5\times0.249376\times0.2=-0.00306568 .
$$

路径二（经隐单元 2）：

$$
\delta_2\cdot W_{2,2}\cdot\sigma'(z_{1,2})\cdot W_{1,21}
=(-0.122934)\times(-0.8)\times0.248599\times0.3=0.00733470 .
$$

$$
\frac{\partial L}{\partial x_1}=-0.00306568+0.00733470=0.00426902 .
$$

用矩阵算：$\partial L/\partial x=W_1^{\mathsf T}\delta_1=(0.2,-0.4;0.3,0.1)^{\mathsf T}(\delta_{1,1},\delta_{1,2})$，第一分量 $0.2\times(-0.015328)+0.3\times0.024449=0.004269$，一致。

**这就是反向传播的全部结构**：每个 $\delta$ 已经把"从损失到该层"的所有路径汇总好了；求某层参数梯度时，只需再乘本层输入。

## 8 矩阵形式与批量

单样本时就是上面。批量 $m$ 个样本时，把 $x$ 堆成 $d\times m$ 的矩阵 $X$：

| 量 | 形状 |
|---|---|
| $X$ | $d\times m$ |
| $Z_1=\sigma(Z_1)$ 前 | $h\times m$ |
| $A_1$ | $h\times m$ |
| $Z_2,\hat Y$ | $c\times m$ |
| $\delta_2$ | $c\times m$ |
| $\delta_1$ | $h\times m$ |
| $\partial L/\partial W_1$ | $h\times d$ |
| $\partial L/\partial W_2$ | $c\times h$ |

$$
\delta_1=(W_2^{\mathsf T}\delta_2)\odot\sigma'(Z_1)
\quad(h\times c)(c\times m)=h\times m,
$$

$$
\frac{\partial L}{\partial W_1}=\frac1m\delta_1X^{\mathsf T}
\quad(h\times m)(m\times d)=h\times d,
$$

$$
\frac{\partial L}{\partial W_2}=\frac1m\delta_2A_1^{\mathsf T}
\quad(c\times m)(m\times h)=c\times h .
$$

**批量只是把"求和"藏进矩阵乘法**，公式形式不变。

## 9 数值梯度检验

反向传播推错时，用中心差分对照最可靠：

$$
\frac{\partial L}{\partial\theta}\approx\frac{L(\theta+\epsilon)-L(\theta-\epsilon)}{2\epsilon},\qquad\epsilon=10^{-6}.
$$

对本题的四个参数抽查：

| 参数 | 解析梯度 | 数值梯度 |
|---|---|---|
| $W_{1,11}$ | $-0.015328$ | $-0.01532834$ |
| $W_{1,21}$ | $0.024449$ | $0.02444892$ |
| $W_{2,1}$ | $-0.064538$ | $-0.06453754$ |
| $b_2$ | $-0.122934$ | $-0.12293352$ |

误差在 $10^{-8}$ 量级，说明推导与实现无误。

## 10 更新一步，损失如何变

取学习率 $\eta=0.1$，九个参数同时更新（沿负梯度）：

$$
W_1'=W_1-0.1\frac{\partial L}{\partial W_1}
=\begin{pmatrix}0.201533&-0.399234\\0.297555&0.098778\end{pmatrix},
$$

$$
b_1'=(0.101533,\ -0.202445),\quad
W_2'=(0.506454,\ -0.793393),\quad b_2'=0.212293 .
$$

重新前向：

$$
\hat y'=0.513322,\qquad L'=\frac12(0.513322-1)^2=0.118428 .
$$

损失从 $0.120965$ 降到 $0.118428$。

若**只更新输出层**（$W_2,b_2$）：$\hat y=0.512942$、$L=0.118613$——也下降，但比全参数更新少一点。这说明隐层的梯度确实在起作用。

## 11 为什么反向传播快

参数总数 $P=9$。若用数值差分求每个参数的梯度，需要 $2P=18$ 次前向；反向传播一次前向 + 一次反向就得到全部 9 个梯度。$P=10^7$ 时，前者要两千万次前向，后者两次。

省下来的关键是**复用**：$\delta_2$ 只算一次，$W_2$ 的梯度、$\delta_1$、$b_2$ 的梯度都用它；$\delta_1$ 只算一次，$W_1$ 与 $b_1$ 的梯度都用它。每一层的 $\delta$ 是"该层以下所有路径的总和"，算一次即共享给该层所有参数。

## 12 十个常见误解

1. **$\delta$ 不是梯度**。$\delta_l=\partial L/\partial z_l$；参数梯度是 $\delta_l$ 乘输入。
2. **忘记转置**。$W_2^{\mathsf T}\delta_2$ 与 $W_2\delta_2$ 形状不同；形状检查能立刻发现。
3. **忘记 $\sigma'$**。少了它，网络等价于线性模型，深层没有意义。
4. **符号弄反**。$\partial L/\partial\hat y=\hat y-y$，不是 $y-\hat y$；配合 $w\leftarrow w-\eta g$ 使用。
5. **批量忘记除以 $m$**。损失是平均值时梯度也要平均。
6. **只更新部分参数**。九个参数都要更新，隐层不更新等于只训练了最后一层。
7. **把 $\delta$ 当学习率**。学习率是超参数，$\delta$ 是逐样本、逐层的量。
8. **混淆"前向存什么"**。要存 $z$（为了 $\sigma'$）和 $a$（为了参数梯度），只存 $\hat y$ 不够。
9. **样本梯度累加错误**。批量里是求和/平均，不是逐样本更新后相加（随机梯度下降除外）。
10. **以为反向传播是优化器**。它只负责算梯度；SGD/Adam 才负责怎么走。

## 13 手算练习（附答案）

**练习 1.** 求 $\partial L/\partial W_{2,2}$ 与 $\partial L/\partial b_2$。

**练习 2.** 把目标改成 $y=0$，重新算 $\delta_2,\delta_1$ 与 $\partial L/\partial W_1$。

**练习 3.** 若 $W_2=(0.5,0.5)$，其余不变，$\delta_1$ 是多少？与原来比说明什么？

**练习 4.** 为什么 $\partial L/\partial b_1=\delta_1$，而 $\partial L/\partial W_1=\delta_1x^{\mathsf T}$？

**练习 5.** 两个样本的梯度分别为 $(0.2,-0.4)$ 与 $(-0.1,0.3)$，批量梯度是多少？

**答案.**

1. $\partial L/\partial W_{2,2}=\delta_2a_{1,2}=-0.066068$；$\partial L/\partial b_2=-0.122934$。
2. $\hat y=0.508136$ 不变，$\delta_2=(0.508136-0)(0.249934)=0.127000$；$W_2^{\mathsf T}\delta_2=(0.063500,-0.101600)$，乘 $\sigma'$ 得 $\delta_1=(0.015835,-0.025258)$；$\partial L/\partial W_1=\begin{pmatrix}0.015835&0.007918\\-0.025258&-0.012629\end{pmatrix}$。
3. $W_2^{\mathsf T}\delta_2=(-0.061467,-0.061467)$，$\delta_1=(-0.015328,-0.015281)$。两个隐单元的误差几乎相同，因为输出层给它们的权重相同。
4. $b_1$ 的"输入"是常数 1，所以梯度就是 $\delta_1$；$W_1$ 的输入是 $x$，所以每个元素要乘对应的输入分量，矩阵形式就是外积 $\delta_1x^{\mathsf T}$。
5. 平均值：$((0.2-0.1)/2,\ (-0.4+0.3)/2)=(0.05,-0.05)$。
