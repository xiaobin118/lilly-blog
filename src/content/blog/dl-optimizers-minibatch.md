---
title: "第 4 步：优化器与小批量训练"
description: "实现三种优化器和一个训练循环："
date: 2026-10-20
tags: [deep-learning]
type: note
topic: "深度学习"
---

> 对应代码：`learn/practice/step04_train.py`
>
> 前置：第 3 步 7/7 通过，`MLP.loss_and_grads` 能给出正确的梯度。
>
> 本步预计 1.5～2 小时。目标是让 MLP 第一次真正"学起来"：在 MNIST 子集上跑过 95%。

## 1. 本步目标

实现三种优化器和一个训练循环：

1. **SGD**：最朴素的梯度下降；
2. **Momentum**：用历史梯度平滑方向、加速；
3. **Adam**：为每个参数自适应地缩放步长；
4. **`fit`**：按 epoch 打乱数据、切小批量、更新参数、记录训练/测试曲线。

完成后你应该能：

- 说清 `epoch`、`batch`、`iteration` 三个词的区别；
- 解释为什么批大小会同时影响"梯度噪声"和"更新次数"；
- 看懂训练曲线上"训练损失下降、测试准确率不涨"意味着什么。

## 2. 为什么还需要优化器

第 3 步已经能算梯度，最直接的更新是

$$
\theta\leftarrow\theta-\eta g,
$$

这就是 SGD。但在实际训练中它有三个问题：

1. **噪声大**：小批量梯度只是全批量梯度的估计，方向会抖；
2. **曲率不均**：有的方向很陡、有的很平，同一个学习率无法同时适配；
3. **鞍点/平台**：梯度很小的地方会走得很慢。

Momentum 和 Adam 分别针对前两个问题。它们不改变"梯度是什么"，只改变"怎么用梯度走下一步"。

## 3. 三种优化器

### 3.1 SGD

$$
g_t=\nabla_\theta L(\theta_t),\qquad \theta_{t+1}=\theta_t-\eta g_t.
$$

- 每个参数用同一个学习率；
- 简单、内存小；
- 对学习率敏感。

### 3.2 Momentum

维护一个"速度" $v$（初始为 0）：

$$
v_{t+1}=\mu v_t-\eta g_t,\qquad \theta_{t+1}=\theta_t+v_{t+1}.
$$

$v$ 是历史梯度的指数加权平均。直观理解：

- 如果很多步的梯度方向一致，$v$ 会累积，走得更快；
- 如果梯度来回震荡，正负抵消，震荡被压小；
- $\mu=0.9$ 表示"保留 90% 的历史速度"。

注意符号：这里 $v$ 与梯度**反方向**（因为前面有负号），所以更新是 $\theta+v$，不是 $\theta-v$。

### 3.3 Adam

同时估计梯度的一阶矩和二阶矩：

$$
m_t=\beta_1m_{t-1}+(1-\beta_1)g_t,\qquad
v_t=\beta_2v_{t-1}+(1-\beta_2)g_t^2,
$$

偏差修正：

$$
\hat m_t=\frac{m_t}{1-\beta_1^t},\qquad
\hat v_t=\frac{v_t}{1-\beta_2^t},
$$

更新：

$$
\theta_{t+1}=\theta_t-\eta\frac{\hat m_t}{\sqrt{\hat v_t}+\epsilon}.
$$


- $m$ 是梯度的滑动平均（方向）；
- $v$ 是梯度平方的滑动平均（幅度）；
- 除以 $\sqrt{\hat v}$ 让每个参数的步长自动缩放：梯度大的参数步子小，梯度小的参数步子相对大；
- 偏差修正是因为 $m,v$ 初始为 0，前几步会偏小；除以 $1-\beta^t$ 补回来。

常用超参数：$\beta_1=0.9$、$\beta_2=0.999$、$\epsilon=10^{-8}$。

## 4. 小批量训练

### 4.1 三个词

| 词 | 含义 |
|---|---|
| `batch_size` | 一次梯度更新用多少个样本 |
| `iteration` | 一次参数更新（处理一个 batch） |
| `epoch` | 把整个训练集完整过一遍 |

一个 epoch 的更新次数是

$$
\left\lceil\frac{N}{\text{batch\_size}}\right\rceil.
$$

例如 $N=10000$、batch=128，每个 epoch 更新 79 次。

### 4.2 为什么要打乱

如果数据按类别排序，每个 batch 可能全是同一类，梯度会有系统性偏差。每个 epoch 开始前用 `rng.permutation(N)` 打乱一次，让每个 batch 都是近似随机的样本。

### 4.3 批大小的两面性

- **小批量**：梯度噪声大，但每个 epoch 更新次数多，早期收敛快；
- **大批量**：梯度更准，但更新次数少；同样 epoch 数下可能欠拟合。

第 8 节的实验中你会看到：批大小 16 比 128 准确率高，但训练时间更长；全批量在 20 个 epoch 内只有 20 次更新，明显不够。

## 5. 训练循环

```python
for epoch in range(1, epochs + 1):
    order = rng.permutation(N)              # 打乱
    for start in range(0, N, batch_size):
        idx = order[start:start + batch_size]
        loss, grads = model.loss_and_grads(X[idx], y[idx])
        optimizer.step(model.Ws + model.bs, grads)
    # 每个 epoch 结束记录一次
    history.append({...})
```

要记录的量：

- `train_loss`：这个 epoch 各 batch 损失的加权平均；
- `train_acc`：在完整训练集上的准确率；
- `test_acc`：在测试集上的准确率（用来观察泛化）。

## 6. 学习率

| 优化器 | 常用学习率 | 说明 |
|---|---|---|
| SGD | $10^{-2}\sim10^{-1}$ | 对学习率很敏感 |
| Momentum | $10^{-2}$ 左右 | 比 SGD 稳 |
| Adam | $10^{-3}$ | 默认起点 |

学习率太小的典型现象：损失几乎线性缓慢下降；太大：损失震荡或变成 `nan`。先用 Adam + $10^{-3}$ 跑通，再尝试其他组合。

## 7. 实现任务

打开 `practice/step04_train.py`。

### TODO 1：三个优化器

每个优化器是一个类，接口统一：

```python
def step(self, params: list[Array], grads: list[Array]) -> None:
    """原地更新每个参数：params[i] -= ..."""
```

- `SGD.step`：`p -= lr * g`；
- `Momentum.step`：第一次调用时初始化 `self.velocity = [zeros_like(p) ...]`，然后
  `v = momentum * v - lr * g; p += v`；
- `Adam.step`：第一次调用时初始化 `self.m`、`self.v`、`self.t = 0`，每次调用
  `self.t += 1`，按第 3.3 节的公式更新。

注意：`params` 和 `grads` 是**列表**，长度等于 `len(model.Ws) + len(model.bs)`，顺序是"先所有 W，再所有 b"。

### TODO 2：`fit`

按第 5 节的伪代码实现，参数：

| 参数 | 类型 | 含义 |
|---|---|---|
| `model` | `MLP` | 要训练的模型 |
| `X, y` | `Array` | 训练数据 |
| `Xte, yte` | `Array` | 测试数据 |
| `epochs` | `int` | 训练多少轮 |
| `batch_size` | `int` | 每批样本数 |
| `lr` | `float` | 学习率 |
| `optimizer` | `str` | `"sgd"` / `"momentum"` / `"adam"` |
| `l2` | `float` | L2 正则系数，0 表示不正则（第 6 步用到） |
| `seed` | `int` | 打乱数据的随机种子 |

返回 `history`：一个列表，每个 epoch 一个字典，至少包含
`epoch`、`train_loss`、`train_acc`、`test_acc`。

## 8. 自检说明

运行 `python step04_train.py`，七项检查：

| 检查 | 验证什么 |
|---|---|
| 1. SGD | $p=1,g=2,\eta=0.1\Rightarrow p=0.8$ |
| 2. Momentum | 两步后的速度与位置 |
| 3. Adam | 第一步的更新量约为 $-\eta$（偏差修正正确） |
| 4. 更新次数 | 每个 epoch 的 batch 数等于 ceil(N/bs)，且样本不重不漏 |
| 5. 小数据训练 | 二维四团高斯，30 个 epoch，准确率 > 0.95 |
| 6. history 结构 | 长度、字段、损失下降 |
| 7. MNIST 子集 | 3000 张训练、10 个 epoch，测试准确率 > 0.88 |

全过后会跑一个 MNIST 正式演示：10000 张训练、20 个 epoch，目标 > 95%。

## 9. 常见错误

1. **Momentum 的符号反了**：写成 `v = mu*v + lr*g; p -= v`，结果等价但容易和文档对不上；统一用 `v = mu*v - lr*g; p += v`。
2. **Adam 忘记偏差修正**：第一步更新量会小很多，收敛变慢。
3. **`self.t` 在参数循环里自增**：应该每次 `step` 只加 1，不是每个参数加 1。
4. **优化器状态没有按参数初始化**：`self.m`、`self.v` 必须是和 `params` 等长的列表，每个元素形状与对应参数相同。
5. **`fit` 里每个 batch 都重新 `permutation`**：应该每个 epoch 打乱一次，epoch 内按顺序切块。
6. **最后一个 batch 不足 batch_size 时被丢掉**：`range(0, N, bs)` 会自动处理，别写 `range(0, N - N % bs, bs)`。
7. **每步都计算全量测试指标**：太慢；每个 epoch 结束算一次即可。
8. **学习率给错量级**：Adam 用 0.1 会发散，SGD 用 1e-4 会几乎不动。

## 10. 思考题

1. 同样 20 个 epoch，batch=16 和 batch=10000 哪个更新次数多？各是多少次（N=10000）？
2. Adam 的第一步（$t=1$）更新量为什么约等于 $-\eta\cdot\mathrm{sign}(g)$？代入 $\hat m_1$、$\hat v_1$ 算一下。
3. 训练损失一直下降、测试准确率不涨，可能是什么原因？列出两种。

## 11. 小结与下一步

完成后你拥有一个能训练的 MLP：前向、反向、优化器、小批量循环。第 5 步回到二维数据，用这个模型和线性分类器做对照实验，画决策边界，并观察"高斯打平、圆环/螺旋差距巨大"的现象。

---

**完成后发回**：

1. `python step04_train.py` 的完整输出（七项 PASS/FAIL + MNIST 演示准确率）；
2. 你写的 `Adam.step` 和 `fit`；
3. 一句话：为什么 `fit` 要在每个 epoch 开始时打乱数据。
